#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <zpool_name>"
    exit 1
fi

POOL="$1"
ROOT_DS="$POOL/ROOT/debian"

# Load ZFS module
sudo modprobe zfs

# Import pool without auto-mounting
sudo zpool import -N "$POOL"

# Prepare mountpoint
sudo mkdir -p /mnt/newroot
sudo mkdir -p /mnt/newroot/{home,tmp,var,var/log}

# Set mountpoints
sudo zfs set mountpoint=/mnt/newroot "$ROOT_DS"
sudo zfs set mountpoint=/mnt/newroot/home "$POOL/home"
sudo zfs set mountpoint=/mnt/newroot/tmp "$POOL/tmp"
sudo zfs set mountpoint=/mnt/newroot/var "$POOL/var"
sudo zfs set mountpoint=/mnt/newroot/var/log "$POOL/var/log"

# Mount datasets
sudo zfs mount "$ROOT_DS"
sudo zfs mount "$POOL/home"
sudo zfs mount "$POOL/tmp"
sudo zfs mount "$POOL/var"
sudo zfs mount "$POOL/var/log"

echo "ZFS datasets mounted to /mnt/newroot"