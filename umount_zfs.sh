#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <zpool_name>"
    exit 1
fi

POOL="$1"
ROOT_DS="$POOL/ROOT/debian"

# Unmount in reverse order
sudo umount /mnt/newroot/var/log
sudo umount /mnt/newroot/var
sudo umount /mnt/newroot/tmp
sudo umount /mnt/newroot/home
sudo umount /mnt/newroot

# Reset mountpoints
sudo zfs set mountpoint=/ "$ROOT_DS"
sudo zfs set mountpoint=/home "$POOL/home"
sudo zfs set mountpoint=/tmp "$POOL/tmp"
sudo zfs set mountpoint=/var "$POOL/var"
sudo zfs set mountpoint=/var/log "$POOL/var/log"

# Export pool
sudo zpool export "$POOL"

echo "ZFS datasets unmounted and pool exported"