# Copy linux system to new location

## Prep: create and mount the target root filesystem
```
sudo mkfs.ext4 /dev/sdX2                      # or btrfs/xfs as you prefer
sudo mkdir -p /mnt/newroot
```

## Mount (if simple partition)
```
sudo mount /dev/sdX2 /mnt/newroot
```

## mount ZFS

### --- Variables (make the pool generic) ---
```
POOL="rpool-pi5"                 # <-- change if your pool name differs
ROOT_DS="$POOL/ROOT/debian"      # root dataset you want as /
```

### --- Ensure ZFS is available and import the pool without auto-mounting ---
```
sudo modprobe zfs
```

### If the pool is not yet imported, import it WITHOUT mounting datasets:
```
sudo zpool import -N "$POOL"
```

### --- Prepare the target tree under /mnt/newroot ---
```
sudo mkdir -p /mnt/newroot
sudo mkdir -p /mnt/newroot/{home,tmp,var,var/log}
```

### Set mountpoints for a newroot
```
sudo zfs set mountpoint=/mnt/newroot        "$ROOT_DS"
sudo zfs set mountpoint=/mnt/newroot/home    "$POOL/home"
sudo zfs set mountpoint=/mnt/newroot/tmp     "$POOL/tmp"
sudo zfs set mountpoint=/mnt/newroot/var     "$POOL/var"
sudo zfs set mountpoint=/mnt/newroot/var/log "$POOL/var/log"
```

### --- (B) Manually mount the datasets using `zfs mount` (NOT `mount`) ---
### Because canmount is disabled for auto-mount, we explicitly mount:
```
sudo zfs mount "$ROOT_DS"
sudo zfs mount "$POOL/home"
sudo zfs mount "$POOL/tmp"
sudo zfs mount "$POOL/var"
sudo zfs mount "$POOL/var/log"
```

### (Optional) Verify mounts:
```
mount | grep -E "^$POOL|zfs .* /mnt/newroot"
zfs list -o name,mountpoint | grep "^$POOL"
```

### --- After your one-pass rsync, cleanly unmount everything ---
### Unmount in reverse order (or use -R if supported).
```
sudo umount /mnt/newroot/var/log
sudo umount /mnt/newroot/var
sudo umount /mnt/newroot/tmp
sudo umount /mnt/newroot/home
sudo umount /mnt/newroot
```

### reset correct mountpoint for zfs datasets:
```
sudo zfs set mountpoint=/ "$ROOT_DS"
sudo zfs set mountpoint=/home "$POOL/home"
sudo zfs set mountpoint=/tmp "$POOL/tmp"
sudo zfs set mountpoint=/var "$POOL/var"
sudo zfs set mountpoint=/var/log "$POOL/var/log"
```

### If you imported the pool in this session and want to detach it:
```
sudo zpool export "$POOL"
```

## 1) FIRST PASS: copy everything except volatile/pseudo mounts and /boot (you said boot stays)
-a     : archive (rlptgoD)
-A -X  : preserve ACLs and xattrs (capabilities live in xattrs!)
-H     : preserve hardlinks
-S     : handle sparse files intelligently
-x     : don’t cross filesystem boundaries
--numeric-ids : don’t map uid/gid names
--delete      : make target an exact mirror (omit on first run if you’re nervous)
```
sudo rsync -aAXHSxv \
  --numeric-ids \
  --delete \
  --exclude={"/boot/*","/dev/*","/proc/*","/sys/*","/run/*","/tmp/*","/mnt/*","/media/*","/lost+found"} \
  / /mnt/newroot
```

# Using `chroot` on Raspberry Pi OS / Debian

This guide shows the exact order to prepare, enter, and cleanly exit a chroot. It keeps `/boot` untouched and ensures networking works inside the chroot.

---

## 1) Mount the target root filesystem

Mount the partition that will act as the chroot’s `/` (example device: `/dev/sda2`):
```
sudo mkdir -p /mnt/newroot
sudo mount /dev/sda2 /mnt/newroot
```

---

## 2) Copy DNS configuration **before** mounting virtual filesystems (if using debootstrap - fresh system)

Copy the host’s resolver so DNS works inside the chroot. This version follows symlinks (common on systemd hosts):

```
sudo mkdir -p /mnt/newroot/etc
sudo cp -L /etc/resolv.conf /mnt/newroot/etc/resolv.conf
```

Optional: also copy minimal host mappings if you rely on them:
```
sudo cp -L /etc/hosts /mnt/newroot/etc/hosts
```

---

## 3) Bind-mount essential virtual filesystems

These mounts make the chroot behave like a real system (devices, processes, runtime data):
```
# PROC
sudo mount -t proc /proc /mnt/newroot/proc

# SYS (bind, then make it a slave so mount events don't leak back)
sudo mount --rbind /sys /mnt/newroot/sys
sudo mount --make-rslave /mnt/newroot/sys

# DEV
sudo mount --rbind /dev /mnt/newroot/dev
sudo mount --make-rslave /mnt/newroot/dev

# RUN
sudo mount --rbind /run /mnt/newroot/run
sudo mount --make-rslave /mnt/newroot/run
```
- `--rbind` = recursive bind (includes all submounts).
- `--make-rslave` = prevents mount/unmount events from leaking back to the host.

---

## 4) Enter the chroot
```
sudo chroot /mnt/newroot /bin/bash
```

Confirm you are inside the new root:
```
ls /
```

---

## 5) Work inside the chroot

Run any commands you need, for example:
```
apt update
apt install raspberrypi-kernel firmware-brcm80211
```

Exit when done:
```
exit
```

(or press `Ctrl+D`)

---

## 6) Cleanly unmount everything (reverse order)

Unmount in the reverse order that you mounted. Use lazy unmounts if something still holds a reference:

```
sudo umount -l /mnt/newroot/run
sudo umount -l /mnt/newroot/dev
sudo umount -l /mnt/newroot/sys
sudo umount -l /mnt/newroot/proc
sudo umount /mnt/newroot
```

# Boot into ZFS partition

## 1. Update initramfs

Inside chroot:
```
update-initramfs -c -k all
```

## 2. Identify your root dataset

Your root dataset is $ROOT_DS = rpool-pi5/ROOT/debian.
ZFS usually expects a bootfs property on the pool:
```
sudo zpool set bootfs=rpool-pi5/ROOT/debian rpool-pi5
```

## 3. Adjust /etc/default/zfs

Inside the new root, check:
```
cat /etc/default/zfs | grep ZFS_INITRD
```
It should have:
```
ZFS_INITRD_ADDITIONAL_DATASETS="rpool-pi5/ROOT/debian"
```
If not, add it and re-run update-initramfs.


## 4. Adjust /etc/fstab in the new root

Your root dataset should not appear in /etc/fstab (it’s mounted by ZFS).
Only things like /boot (your old boot partition) and maybe swap should be in fstab. Example:
```
PARTUUID=xxxx-yy  /boot  vfat  defaults  0  2
```

## 5. Edit /boot/cmdline.txt

This is Pi-specific: the firmware reads /boot/cmdline.txt and passes it to the kernel.
You need to set root= to use ZFS. Example:
```
root=ZFS=rpool-pi5/ROOT/debian rw rootwait
boot=zfs
```

So a working line might look like:
```
console=serial0,115200 console=tty1 root=ZFS=rpool-pi5/ROOT/debian rootfstype=zfs boot=zfs rw rootwait
```

Keep all other options from your original cmdline.txt. Just replace the old root=PARTUUID=... with root=ZFS=....
