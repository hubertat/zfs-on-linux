#!/usr/bin/env bash
set -Eeuo pipefail

# Bind-mount the essential virtual filesystems into /mnt/newroot and chroot in.
# Usage: sudo ./mount_and_chroot.sh [--copy-dns]
#   --copy-dns   copy host /etc/resolv.conf and /etc/hosts first (debootstrap)

MOUNT_POINT="/mnt/newroot"
COPY_DNS=false

if [ "${1:-}" = "--copy-dns" ]; then
    COPY_DNS=true
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must be run as root (use sudo)." >&2
    exit 1
fi

if [ ! -d "$MOUNT_POINT" ]; then
    echo "ERROR: $MOUNT_POINT does not exist. Mount the target root first (see mount_zfs.sh)." >&2
    exit 1
fi

if ! mountpoint -q "$MOUNT_POINT"; then
    echo "WARNING: $MOUNT_POINT is not a mountpoint — is the target root mounted?" >&2
fi

# Copy DNS configuration if requested
if [ "$COPY_DNS" = true ]; then
    echo "Copying DNS configuration..."
    mkdir -p "$MOUNT_POINT/etc"
    cp -L /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf"
    cp -L /etc/hosts "$MOUNT_POINT/etc/hosts"
fi

# Bind-mount essential virtual filesystems
mount -t proc /proc "$MOUNT_POINT/proc"
mount --rbind /sys "$MOUNT_POINT/sys"
mount --make-rslave "$MOUNT_POINT/sys"
mount --rbind /dev "$MOUNT_POINT/dev"
mount --make-rslave "$MOUNT_POINT/dev"
mount --rbind /run "$MOUNT_POINT/run"
mount --make-rslave "$MOUNT_POINT/run"

# Enter the chroot. Don't let a non-zero exit from the interactive shell abort
# the script before the reminder prints.
chroot "$MOUNT_POINT" /bin/bash || true

echo "Exited chroot. Remember to unmount with: sudo ./umount_chroot.sh"
