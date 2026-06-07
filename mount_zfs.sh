#!/usr/bin/env bash
set -Eeuo pipefail

# Point the project's dataset layout at /mnt/newroot and mount it there.
# Usage: sudo ./mount_zfs.sh <zpool_name>

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
    echo "ERROR: pool '$POOL' not found (import it first, e.g. zpool import -N $POOL)." >&2
    exit 1
fi

if ! zfs list -H -o name "$ROOT_DS" >/dev/null 2>&1; then
    echo "ERROR: root dataset '$ROOT_DS' not found." >&2
    exit 1
fi

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
