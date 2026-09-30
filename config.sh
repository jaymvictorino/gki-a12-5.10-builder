#!/usr/bin/env bash
# config.sh — Patched for ramabondanp/android_kernel_common-5.10 (vanilla GKI)
#
# CHANGES vs. upstream SuiKernel builder:
#   - KERNEL_REPO   → ramabondanp/android_kernel_common-5.10
#   - KERNEL_BRANCH → android12-5.10
#   - CLANG_URL     → clang-r563880b (matches build.config.common in this tree)
#   - KERNEL_NAME   → GKI-Kernel (neutral branding for vanilla build)
#
# After saving this file, run:  chmod +x *.sh

# ---------------------------------------------------------------------------
# Kernel branding
# ---------------------------------------------------------------------------
KERNEL_NAME="GKI-Kernel"

# ---------------------------------------------------------------------------
# Build environment
# ---------------------------------------------------------------------------
USER="builder"
HOST="gki-builder"
TIMEZONE="Asia/Jakarta"          # Change to your local TZ if desired

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
GKI_RELEASES_REPO="https://github.com/jaymvictorino/gki-a12-5.10-builder"

# ---------------------------------------------------------------------------
# Clang toolchain  ← THE SECOND KEY CHANGE
# ---------------------------------------------------------------------------
# build.config.common in ramabondanp's tree says:
#   "ANDROID: Use google clang 21.0.0 (clang-r563880b)"
# Using an older Clang (e.g. r416183b) will fail or produce ABI-unsafe output.
#
# This is the archive URL of the exact commit tagged clang-r563880b in
# android.googlesource.com/platform/prebuilts/clang/host/linux-x86
CLANG_URL="https://github.com/bachnxuan/aosp_clang_mirror/releases/download/clang-r614150-16464736/clang-r614150.tar.gz"
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
