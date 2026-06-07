#!/usr/bin/env bash
set -Eeuo pipefail

# Unmount the chroot's virtual filesystems (reverse order, lazy).
# Usage: sudo ./umount_chroot.sh

MOUNT_POINT="/mnt/newroot"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must be run as root (use sudo)." >&2
    exit 1
fi

# Unmount in reverse order. Lazy unmount handles lingering references; skip any
# that aren't mounted so a partial setup still cleans up cleanly.
for sub in run dev sys proc; do
    mp="$MOUNT_POINT/$sub"
    if mount | grep -q " $mp "; then
        umount -l "$mp" || echo "WARNING: failed to unmount $mp" >&2
    fi
done

echo "Chroot virtual filesystems unmounted"
