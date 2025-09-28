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
    sudo mkdir -p "$MOUNT_POINT/etc"
    sudo cp -L /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf"
    sudo cp -L /etc/hosts "$MOUNT_POINT/etc/hosts"
fi

# Bind-mount essential virtual filesystems
sudo mount -t proc /proc "$MOUNT_POINT/proc"
sudo mount --rbind /sys "$MOUNT_POINT/sys"
sudo mount --make-rslave "$MOUNT_POINT/sys"
sudo mount --rbind /dev "$MOUNT_POINT/dev"
sudo mount --make-rslave "$MOUNT_POINT/dev"
sudo mount --rbind /run "$MOUNT_POINT/run"
sudo mount --make-rslave "$MOUNT_POINT/run"

# Enter the chroot
sudo chroot "$MOUNT_POINT" /bin/bash

echo "Exited chroot"
