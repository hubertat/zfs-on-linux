#!/bin/bash

MOUNT_POINT="/mnt/newroot"

# Unmount in reverse order
sudo umount -l "$MOUNT_POINT/run"
sudo umount -l "$MOUNT_POINT/dev"
sudo umount -l "$MOUNT_POINT/sys"
sudo umount -l "$MOUNT_POINT/proc"

echo "Chroot virtual filesystems unmounted"