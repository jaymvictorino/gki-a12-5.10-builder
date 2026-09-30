#!/usr/bin/env bash
# build.sh — Vanilla GKI build for ramabondanp/android_kernel_common-5.10
#
# PATCHED for GitHub Actions reliability:
#   - LTO disabled (cuts build time ~3x, RAM usage ~2x)
#   - CFI disabled (required when LTO is off)
#   - ccache integration (set CCACHE_DIR env + PATH to /usr/lib/ccache in workflow)
#
# Usage:  ./build.sh
# Output: ./GKI-Kernel-<version>.zip

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths and setup
# ---------------------------------------------------------------------------
workdir="$(pwd)"
BUILD_START=$(date +%s)

exec > >(tee "$workdir/build.log") 2>&1
trap 'echo "[ERROR] Failed at line $LINENO [$BASH_COMMAND]"' ERR

source "$workdir/config.sh"
source "$workdir/functions.sh"

export TZ="$TIMEZONE"

# ---------------------------------------------------------------------------
# ccache — enable if available on PATH
# ---------------------------------------------------------------------------
if command -v ccache >/dev/null 2>&1; then
  export CC="ccache clang"
  export HOSTCC="ccache gcc"
  export CCACHE_DIR="${CCACHE_DIR:-$workdir/.ccache}"
  export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-3G}"
  export CCACHE_COMPRESS=1
  export CCACHE_COMPILERCHECK=content
  mkdir -p "$CCACHE_DIR"
  log "ccache enabled — dir: $CCACHE_DIR, max: $CCACHE_MAXSIZE"
  ccache -z >/dev/null 2>&1 || true
else
  log "ccache not found — building without cache"
fi

# ---------------------------------------------------------------------------
# Clone kernel source
# ---------------------------------------------------------------------------
KSRC="$workdir/ksrc"
rm -rf "$KSRC"
log "Cloning kernel source from $(simplify_gh_url "$KERNEL_REPO") (branch: $KERNEL_BRANCH)"
git clone -q --depth=1 "$KERNEL_REPO" -b "$KERNEL_BRANCH" "$KSRC"

cd "$KSRC"
LINUX_VERSION=$(make kernelversion)
DEFCONFIG_FILE=$(find ./arch/arm64/configs -name "$KERNEL_DEFCONFIG" | head -n1)

if [[ -z "$DEFCONFIG_FILE" ]]; then
  echo "[ERROR] Could not find defconfig: $KERNEL_DEFCONFIG"
  exit 1
fi
log "Linux version: $LINUX_VERSION"
log "Defconfig: $DEFCONFIG_FILE"
cd "$workdir"

# ---------------------------------------------------------------------------
# Download Clang
# ---------------------------------------------------------------------------
CLANG_DIR="$workdir/clang"
rm -rf "$CLANG_DIR"
mkdir -p "$CLANG_DIR"

log "Downloading Clang from $CLANG_URL"
if ! aria2c -q -c -x16 -s32 -k8M --file-allocation=falloc --timeout=60 --retry-wait=5 \
       -o clang.tar.gz "$CLANG_URL"; then
  log "aria2c failed, falling back to curl..."
  curl -fL --retry 5 -o clang.tar.gz "$CLANG_URL"
fi

tar -xf clang.tar.gz -C "$CLANG_DIR"
rm -f clang.tar.gz

if [[ $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ]] \
   && [[ $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type f | wc -l) -eq 0 ]]; then
  SINGLE_DIR=$(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type d)
  mv "$SINGLE_DIR"/* "$CLANG_DIR"/
  rm -rf "$SINGLE_DIR"
fi

export PATH="$CLANG_DIR/bin:$PATH"
CLANG_VERSION=$(clang -v 2>&1 | head -n1 | grep -oP 'clang version \K[0-9.]+' || echo "unknown")
log "Clang version: $CLANG_VERSION"

# ---------------------------------------------------------------------------
# GCC cross-compiler
# ---------------------------------------------------------------------------
if ! ls "$CLANG_DIR/bin" | grep -q "aarch64-linux-gnu"; then
  log "Cloning GCC cross-compiler..."
  git clone --depth=1 -q \
    https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-gnu-9.3 \
    "$workdir/gcc"
  export PATH="$workdir/gcc/bin:$PATH"
  CROSS_COMPILE_PREFIX="aarch64-linux-"
else
  CROSS_COMPILE_PREFIX="aarch64-linux-gnu-"
fi

# ---------------------------------------------------------------------------
# Build flags
# ---------------------------------------------------------------------------
BUILD_FLAGS=(
  "-j$(nproc --all)"
  "ARCH=arm64"
  "LLVM=1"
  "LLVM_IAS=1"
  "O=out"
  "CROSS_COMPILE=$CROSS_COMPILE_PREFIX"
)

KERNEL_IMAGE="$KSRC/out/arch/arm64/boot/Image"
MODULE_SYMVERS="$KSRC/out/Module.symvers"
KMI_CHECK="$workdir/scripts/KMI_function_symbols_test.py"
ABI_XML="$KSRC/android/abi_gki_aarch64.xml"

export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOST"
export KBUILD_BUILD_TIMESTAMP="$(date)"

# ---------------------------------------------------------------------------
# Config tweaks — branding + CI-friendly build optimizations
# ---------------------------------------------------------------------------
cd "$KSRC"
if [ -f "./build.config.gki" ]; then
  sed -i 's/check_defconfig//' ./build.config.gki
fi

BRAND_SUFFIX="-${KERNEL_NAME}-Vanilla"

CONFIG_OPTS=(
  --file "$DEFCONFIG_FILE"
  --disable CONFIG_LOCALVERSION_AUTO
  --set-str CONFIG_LOCALVERSION "$BRAND_SUFFIX"
)

# --- CI-BUILD OPTIMIZATIONS -----------------------------------------------
# Disable LTO + CFI: these triple build time and blow past 6 GB RAM on the
# free GitHub Actions runner, causing preemption mid-link.
CONFIG_OPTS+=(
  --disable LTO_CLANG
  --disable LTO_CLANG_THIN
  --disable LTO_CLANG_FULL
  --disable CFI_CLANG
  --enable  LTO_NONE
)
# --------------------------------------------------------------------------

./scripts/config "${CONFIG_OPTS[@]}"

CURRENT_KERNEL_RELEASE_NAME="${LINUX_VERSION}${BRAND_SUFFIX}"
log "Kernel release string: $CURRENT_KERNEL_RELEASE_NAME"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
log "Generating config..."
make "${BUILD_FLAGS[@]}" "$KERNEL_DEFCONFIG"

log "Building kernel Image + modules (no LTO)..."
make "${BUILD_FLAGS[@]}" Image modules

# ---------------------------------------------------------------------------
# KMI / ABI symbol check
# ---------------------------------------------------------------------------
if [[ -f "$ABI_XML" && -f "$MODULE_SYMVERS" && -f "$KMI_CHECK" ]]; then
  log "Running GKI KMI symbol check..."
  python3 "$KMI_CHECK" "$ABI_XML" "$MODULE_SYMVERS" || {
    log "WARNING: KMI check reported issues — see output above."
  }
else
  log "Skipping KMI check (missing ABI xml / symvers / script)"
fi

# ---------------------------------------------------------------------------
# ccache stats (if enabled)
# ---------------------------------------------------------------------------
if command -v ccache >/dev/null 2>&1; then
  log "ccache stats:"
  ccache -s || true
fi

# ---------------------------------------------------------------------------
# Package with AnyKernel
# ---------------------------------------------------------------------------
cd "$workdir"
log "Cloning AnyKernel from $(simplify_gh_url "$ANYKERNEL_REPO")"
rm -rf anykernel_base anykernel
git clone -q --depth=1 "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" anykernel_base
cp -r anykernel_base anykernel

if [ -f "$KERNEL_IMAGE" ]; then
  cp "$KERNEL_IMAGE" anykernel/
else
  log "WARNING: kernel Image not found at $KERNEL_IMAGE"
fi
sed -i "s/kernel.string=.*/kernel.string=${CURRENT_KERNEL_RELEASE_NAME}/g" anykernel/anykernel.sh

ZIP_NAME="${CURRENT_KERNEL_RELEASE_NAME}.zip"
cd anykernel
log "Creating flashable ZIP: $ZIP_NAME"
zip -r9 "$workdir/$ZIP_NAME" ./* >/dev/null
cd "$workdir"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
BUILD_END=$(date +%s)
BUILD_DIFF=$((BUILD_END - BUILD_START))
BUILD_MINS=$((BUILD_DIFF / 60))
BUILD_SECS=$((BUILD_DIFF % 60))

log "================================================="
log " BUILD COMPLETE"
log "================================================="
log " Kernel:  $CURRENT_KERNEL_RELEASE_NAME"
log " Clang:   $CLANG_VERSION"
log " Time:    ${BUILD_MINS}m ${BUILD_SECS}s"
log " Output:  $workdir/$ZIP_NAME"
log "================================================="
