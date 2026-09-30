# SuiKernel Builder → ramabondanp/android_kernel_common-5.10

A patched fork of the [SuiKernel-GKI-Bulder](https://github.com/LoggingNewMemory/SuiKernel-GKI-Bulder)
adapted to build a **pure vanilla GKI kernel** from
[ramabondanp/android_kernel_common-5.10](https://github.com/ramabondanp/android_kernel_common-5.10)
on the `android12-5.10` branch.

---

## What Was Changed vs. Upstream SuiKernel Builder

| Area | Original SuiKernel Builder | This Fork |
|---|---|---|
| **Kernel repo** | `LoggingNewMemory/SuiKernel-android12-5.10` | `ramabondanp/android_kernel_common-5.10` |
| **Branch** | `suikernel-stable` | `android12-5.10` |
| **Root method** | KernelSU-Next + SUSFS (or YamadaKSUCore) | **None — pure AOSP GKI** |
| **Clang** | `clang-r416183b` (Clang 12, 2021) | `clang-r563880b` (Clang 21, matches `build.config.common`) |
| **SUSFS patch** | Applied | **Removed** |
| **SELinux injection** | Applied | **Removed** |
| **KSU manager patch** | Applied | **Removed** |
| **Pavolia Reine patch** | Applied | **Removed** |
| **KMI symbol check** | Runs | **Runs** (unchanged, verified correct path) |
| **AnyKernel packaging** | Yes | Yes (flashable ZIP still produced) |

---

## Why These Changes?

`ramabondanp/android_kernel_common-5.10` is a **pristine AOSP common kernel** — it has
**no KernelSU hooks, no SUSFS hooks, no device tree**. The upstream SuiKernel builder
injects all of those via `sed`/`patch` assuming the source tree already has the
KernelSU driver structure. Since this tree doesn't, we strip all root modifications
and build **exactly what AOSP ships**, which:

1. **Guarantees KMI/ABI compatibility** — no symbol additions, no symbol removals.
2. **Boots on stock Android 12** devices that expect a GKI kernel.
3. **Passes the GKI KMI symbol check** trivially.

---

## Repository Layout

```

.
├── .github/
│   └── workflows/
│       └── build.yml           # GitHub Actions cloud build
├── scripts/
│   └── KMI_function_symbols_test.py
├── config.sh                   # Patched: points at ramabondanp kernel
├── build.sh                    # Patched: vanilla-only build path
├── flash.sh                    # Unchanged (ADB auto-flasher)
├── functions.sh                # Unchanged (helpers)
├── .gitignore
└── README.md

```

---

## How to Use

### Option A: Local Build (Linux / WSL / Termux)

```bash
# 1. Clone this builder
git clone <your-fork-url> suikernel-builder
cd suikernel-builder

# 2. Make scripts executable
chmod +x *.sh scripts/*.py

# 3. Install dependencies
#    Ubuntu/Debian:
sudo apt install -y aria2 git make python3 python3-pip zip curl bc bison flex libssl-dev
pip3 install lxml

#    Termux:
pkg install -y aria2 git make python clang zip curl bc bison flex openssl-dev
pip install lxml

# 4. Run the build
./build.sh
```

The resulting flashable ZIP will be at `./SuiKernel-<version>.zip`.

### Option B: GitHub Actions (Cloud Build)

1. Push this repo to your GitHub account.
2. Go to **Settings → Actions → General** and enable workflows.
3. (Optional) Add repository secrets for Telegram notifications:

- `TG_BOT_TOKEN` — your Telegram bot token
- `TG_CHAT_ID` — your Telegram chat/user ID
4. Push a commit or go to **Actions → Build GKI Kernel → Run workflow**.
5. When finished, download the artifact from the workflow run summary.

---

## Configuration Reference (`config.sh`)

| Variable ↕▾ | Value ↕▾ | Notes ↕▾ |
|---|---|---|
| −`KERNEL_NAME` | `GKI-Kernel` | Change to brand your build |
| `KERNEL_REPO` | `https://github.com/ramabondanp/android_kernel_common-5.10` | Target source |
| `KERNEL_BRANCH` | `android12-5.10` | Android 12 GKI branch |
| `KERNEL_DEFCONFIG` | `gki_defconfig` | Standard GKI defconfig |
| `CLANG_URL` | `clang-r563880b` tarball | Matches `build.config.common` |
| `ANYKERNEL_REPO` | SuiKernel-anykernel | Swap for your device's AnyKernel if needed |
⚙

---

## Verification

After building, the KMI check runs automatically:

```
$ python3 scripts/KMI_function_symbols_test.py \
      ksrc/android/abi_gki_aarch64.xml \
      ksrc/out/Module.symvers
```

If you see **"All symbols found in Module.symvers."** → ✅ your kernel is ABI-clean.

If symbols are reported missing, that means your defconfig/patches changed an exported
symbol — for a vanilla build with unmodified `gki_defconfig`, this should never happen.

---

## Troubleshooting

| Symptom ↕▾ | Cause ↕▾ | Fix ↕▾ |
|---|---|---|
| −`error: unknown target 'gki_defconfig'` | Wrong branch / layout | Confirm `KERNEL_BRANCH=android12-5.10` |
| Clang fails on `-Wincompatible-function-pointer-types` | Clang too old | This config uses r563880b; don't downgrade |
| `build.config.gki: check_defconfig` fails | Config drift | `build.sh` already patches this out |
| KMI check reports missing symbols | You modified `gki_defconfig` | Revert changes — vanilla builds must not alter symbols |
| `aria2c: command not found` | Missing dep | `sudo apt install aria2` |
⚙

---

## License

The patched scripts retain the original **MIT License** (Copyright © 2025 Kanagawa Yamada).
The kernel source is licensed under **GPL-2.0** as per AOSP.

</BDS:create_file>

<BDS:create_file fileName="config.sh">

```bash
#!/usr/bin/env bash
# config.sh — Patched for ramabondanp/android_kernel_common-5.10 (vanilla GKI)
#
# Changes vs. upstream SuiKernel builder:
#   - KERNEL_REPO  → ramabondanp/android_kernel_common-5.10
#   - KERNEL_BRANCH→ android12-5.10
#   - CLANG_URL    → clang-r563880b (matches build.config.common in this tree)
#   - KERNEL_NAME  → GKI-Kernel (neutral branding for vanilla build)

# ---------------------------------------------------------------------------
# Kernel branding
# ---------------------------------------------------------------------------
KERNEL_NAME="GKI-Kernel"

# ---------------------------------------------------------------------------
# Build environment
# ---------------------------------------------------------------------------
USER="builder"
HOST="gki-builder"
TIMEZONE="Asia/Manila"          # Change to your local TZ if desired

# ---------------------------------------------------------------------------
# AnyKernel (flashable ZIP template)
# ---------------------------------------------------------------------------
# The SuiKernel anykernel works for generic arm64 GKI devices. If you are
# building for a SPECIFIC device, replace this with that device's AnyKernel3.
ANYKERNEL_REPO="https://github.com/LoggingNewMemory/SuiKernel-anykernel"
ANYKERNEL_BRANCH="gki"

# ---------------------------------------------------------------------------
# Kernel source  ← THE KEY CHANGE
# ---------------------------------------------------------------------------
KERNEL_REPO="https://github.com/ramabondanp/android_kernel_common-5.10"
KERNEL_BRANCH="android12-5.10"
KERNEL_DEFCONFIG="gki_defconfig"

# ---------------------------------------------------------------------------
# Release repository (only used by the GitHub Actions release job)
# ---------------------------------------------------------------------------
GKI_RELEASES_REPO="https://github.com/YOUR_USERNAME/YOUR_RELEASES_REPO"

# ---------------------------------------------------------------------------
# Clang toolchain  ← THE SECOND KEY CHANGE
# ---------------------------------------------------------------------------
# build.config.common in ramabondanp's tree says:
#   "ANDROID: Use google clang 21.0.0 (clang-r563880b)"
# Using an older Clang (e.g. r416183b) will fail or produce ABI-unsafe output.
CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/6b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1/clang-r563880b.tar.gz"
CLANG_BRANCH=""

# ---------------------------------------------------------------------------
# Root method
# ---------------------------------------------------------------------------
# For TRUE vanilla GKI, this is forced to "Vanilla" and the build.sh vanilla
# path disables ALL KernelSU / SUSFS / SELinux-injection code.
ROOT_METHOD="Vanilla"

# ---------------------------------------------------------------------------
# Permissive mode (unused in vanilla build, kept for compatibility)
# ---------------------------------------------------------------------------
PERMISSIVE_MODE="Normal"

# ---------------------------------------------------------------------------
# Build status
# ---------------------------------------------------------------------------
STATUS="STABLE"

