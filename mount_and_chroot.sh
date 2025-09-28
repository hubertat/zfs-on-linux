#!/bin/bash

MOUNT_POINT="/mnt/newroot"
COPY_DNS=false

# Check for optional flag
if [ "$1" = "--copy-dns" ]; then
    COPY_DNS=true
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

# Enter the chroot
chroot "$MOUNT_POINT" /bin/bash

echo "Exited chroot"
