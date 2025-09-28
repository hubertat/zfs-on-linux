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

# Reset mountpoints
zfs set mountpoint=/ "$ROOT_DS"
zfs set mountpoint=/home "$POOL/home"
zfs set mountpoint=/tmp "$POOL/tmp"
zfs set mountpoint=/var "$POOL/var"
zfs set mountpoint=/var/log "$POOL/var/log"

# Export pool
zpool export "$POOL"

echo "ZFS datasets unmounted and pool exported"
