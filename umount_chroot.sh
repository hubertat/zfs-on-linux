#!/bin/bash

MOUNT_POINT="/mnt/newroot"

# Unmount in reverse order
umount -l "$MOUNT_POINT/run"
umount -l "$MOUNT_POINT/dev"
umount -l "$MOUNT_POINT/sys"
umount -l "$MOUNT_POINT/proc"

echo "Chroot virtual filesystems unmounted"
