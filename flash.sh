#!/usr/bin/env bash
# flash.sh — ADB auto-flasher (unchanged from upstream, works with any AnyKernel ZIP)
# Usage: ./flash.sh /path/to/GKI-Kernel-*.zip

set -e

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <path_to_zip_artifact>"
    exit 1
fi

INPUT_ZIP="$1"
if [ ! -f "$INPUT_ZIP" ]; then
    echo "File not found: $INPUT_ZIP"
    exit 1
fi

echo "Using kernel zip: $(basename "$INPUT_ZIP")"
echo "Waiting for device..."
adb wait-for-device

echo "Checking for root access..."
if adb shell "su -c 'echo root_ok'" 2>/dev/null | grep -q 'root_ok'; then
    ROOT_AVAILABLE=true
    echo "[+] Root detected — flashing via root shell."
else
    ROOT_AVAILABLE=false
    echo "[-] No root — will sideload instead."
fi

if [ "$ROOT_AVAILABLE" = true ]; then
    adb push "$INPUT_ZIP" /data/local/tmp/gki-update.zip
    adb shell "su -c '
        rm -rf /data/local/tmp/ak3-tmp
        mkdir -p /data/local/tmp/ak3-tmp
        unzip -oq /data/local/tmp/gki-update.zip -d /data/local/tmp/ak3-tmp >/dev/null 2>&1
        cd /data/local/tmp/ak3-tmp
        export BOOTMODE=true
        sh META-INF/com/google/android/update-binary 2 1 /data/local/tmp/gki-update.zip
        cd /
        rm -rf /data/local/tmp/ak3-tmp /data/local/tmp/gki-update.zip
    '"
    echo "Kernel flashed! Rebooting..."
    adb reboot
else
    adb reboot sideload
    echo "Waiting for sideload mode..."
    while [ "$(adb get-state 2>/dev/null || true)" != "sideload" ]; do
        sleep 2
    done
    adb sideload "$INPUT_ZIP"
fi
