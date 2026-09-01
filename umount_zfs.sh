#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <zpool_name>"
    exit 1
fi

POOL="$1"
ROOT_DS="$POOL/ROOT/debian"

# Unmount in reverse order
umount /mnt/newroot/var/log
umount /mnt/newroot/var
umount /mnt/newroot/tmp
umount /mnt/newroot/home
umount /mnt/newroot

# Restore boot-safe properties.  -u avoids an attempted remount if this
# script is used from a recovery environment where the root dataset is busy.
zfs set -u mountpoint=/ "$ROOT_DS"
zfs set mountpoint=/home "$POOL/home"
zfs set mountpoint=/tmp "$POOL/tmp"
zfs set mountpoint=/var "$POOL/var"
zfs set mountpoint=/var/log "$POOL/var/log"
zfs set canmount=noauto "$ROOT_DS"
zfs set canmount=noauto "$POOL/home"
zfs set canmount=noauto "$POOL/tmp"
zfs set canmount=noauto "$POOL/var"
zfs set canmount=noauto "$POOL/var/log"
zpool set bootfs="$ROOT_DS" "$POOL"

# Export pool
zpool export "$POOL"

echo "ZFS datasets unmounted and pool exported"
