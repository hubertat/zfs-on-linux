#!/usr/bin/env bash
set -Eeuo pipefail

# Unmount the project's dataset layout from /mnt/newroot, reset mountpoints
# back to their real targets, and export the pool.
# Usage: sudo ./umount_zfs.sh <zpool_name>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <zpool_name>" >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must be run as root (use sudo)." >&2
    exit 1
fi

if ! command -v zfs >/dev/null 2>&1; then
    echo "ERROR: zfs command not found." >&2
    exit 1
fi

POOL="$1"
ROOT_DS="$POOL/ROOT/debian"

if ! zpool list -H -o name 2>/dev/null | grep -qx "$POOL"; then
    echo "ERROR: pool '$POOL' not found / not imported." >&2
    exit 1
fi

# Unmount in reverse order. Track failures so we don't blindly export a pool
# that still has busy mounts.
unmount_failed=0
for mp in /mnt/newroot/var/log /mnt/newroot/var /mnt/newroot/tmp /mnt/newroot/home /mnt/newroot; do
    if mountpoint -q "$mp" 2>/dev/null || mount | grep -q " $mp "; then
        if ! umount "$mp"; then
            echo "WARNING: failed to unmount $mp" >&2
            unmount_failed=1
        fi
    fi
done

if [ "$unmount_failed" -ne 0 ]; then
    echo "ERROR: one or more unmounts failed; not resetting mountpoints or exporting." >&2
    echo "       Check 'lsof'/'fuser' for processes holding /mnt/newroot, then retry." >&2
    exit 1
fi

# Reset mountpoints to their real targets
zfs set mountpoint=/ "$ROOT_DS"
zfs set mountpoint=/home "$POOL/home"
zfs set mountpoint=/tmp "$POOL/tmp"
zfs set mountpoint=/var "$POOL/var"
zfs set mountpoint=/var/log "$POOL/var/log"

# Export pool
zpool export "$POOL"

echo "ZFS datasets unmounted and pool exported"
