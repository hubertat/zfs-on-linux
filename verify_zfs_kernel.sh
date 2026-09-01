#!/bin/bash

# Verify that a kernel has the ZFS DKMS module and that its initramfs includes it.
# Usage: ./verify_zfs_kernel.sh [kernel-version]

set -u

if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [kernel-version]" >&2
    exit 2
fi

KERNEL="${1:-$(uname -r)}"
MODULE_DIR="/lib/modules/$KERNEL/updates/dkms"
INITRD="/boot/initrd.img-$KERNEL"
STATUS=0

fail() {
    echo "FAIL: $1" >&2
    STATUS=1
}

echo "Verifying ZFS for kernel: $KERNEL"

if [ ! -d "/lib/modules/$KERNEL" ]; then
    fail "kernel modules directory is missing: /lib/modules/$KERNEL"
fi

if command -v dkms >/dev/null 2>&1; then
    DKMS_STATUS="$(dkms status -m zfs -k "$KERNEL" 2>&1 || true)"
    if printf '%s\n' "$DKMS_STATUS" | grep -q ': installed'; then
        echo "OK: DKMS reports ZFS as installed"
    else
        fail "DKMS does not report ZFS as installed for $KERNEL"
        printf '%s\n' "$DKMS_STATUS" >&2
    fi
else
    fail "dkms command is not available"
fi

MODULE_FOUND=false
for MODULE in "$MODULE_DIR"/zfs.ko "$MODULE_DIR"/zfs.ko.xz "$MODULE_DIR"/zfs.ko.zst "$MODULE_DIR"/zfs.ko.gz; do
    if [ -f "$MODULE" ]; then
        echo "OK: module present: $MODULE"
        MODULE_FOUND=true
        break
    fi
done
if [ "$MODULE_FOUND" = false ]; then
    fail "ZFS module not found below $MODULE_DIR"
fi

if [ ! -f "$INITRD" ]; then
    fail "initramfs is missing: $INITRD"
elif ! command -v lsinitramfs >/dev/null 2>&1; then
    fail "lsinitramfs command is not available"
elif lsinitramfs "$INITRD" | grep -q '/zfs\.ko'; then
    echo "OK: initramfs includes zfs.ko"
else
    fail "initramfs does not include zfs.ko: $INITRD"
fi

if [ "$STATUS" -eq 0 ]; then
    echo "ZFS boot verification passed for $KERNEL"
else
    echo "ZFS boot verification failed for $KERNEL" >&2
fi

exit "$STATUS"
