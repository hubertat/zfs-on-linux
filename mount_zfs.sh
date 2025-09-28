#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <zpool_name>"
    exit 1
fi

POOL="$1"
ROOT_DS="$POOL/ROOT/debian"


# Prepare mountpoint
mkdir -p /mnt/newroot
mkdir -p /mnt/newroot/{home,tmp,var,var/log}

# Set mountpoints
zfs set mountpoint=/mnt/newroot "$ROOT_DS"
zfs set mountpoint=/mnt/newroot/home "$POOL/home"
zfs set mountpoint=/mnt/newroot/tmp "$POOL/tmp"
zfs set mountpoint=/mnt/newroot/var "$POOL/var"
zfs set mountpoint=/mnt/newroot/var/log "$POOL/var/log"

# Mount datasets
zfs mount "$ROOT_DS"
zfs mount "$POOL/home"
zfs mount "$POOL/tmp"
zfs mount "$POOL/var"
zfs mount "$POOL/var/log"

echo "ZFS datasets mounted to /mnt/newroot"
