# install zfs on raspberry pi

From [https://forums.raspberrypi.com/viewtopic.php?t=334421]:


*The below procedure always has worked for me on RPi 3's and 4's*

Same for host and chroot inside new root.

```
sudo apt update
sudo apt install raspberrypi-kernel raspberrypi-kernel-headers zfs-dkms zfs-initramfs zfsutils-linux -y
sudo apt full-upgrade -y
sudo reboot
```

*Once rebooted,*

```
sudo apt autoremove && sudo apt clean
```

Worked OK on rpi 5 on 20.09.2025.

## can't modprobe zfs!

On another fresh install I did above and still got problems to `modprobe zfs`, this `dkms` command helped:
```
sudo dkms autoinstall
sudo modprobe zfs
```

## inside new root (chroot raspberry)
Ensure the ZFS module is included
```
echo zfs | sudo tee -a /etc/initramfs-tools/modules
```



# install zfs on debian (general, intel/amd)

From [https://wiki.debian.org/ZFS] and [https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Buster%20Root%20on%20ZFS.html]

Update apt, remember to add non-free sources, contrib etc.
Install packages:
```
sudo apt update
sudo apt install linux-headers-amd64 dpkg-dev linux-image-amd64
sudo apt install zfs-initramfs zfsutils-linux zfs-dkms
```

In case of problems with zfs module, try:
```
sudo dkms autoinstall -k $(uname -r)
```
After this it should work:
```
sudo modprobe zfs
```

## Keep ZFS packages on one version

Do not mix ZFS packages from Debian, Debian security, and backports. In
particular, do not force DKMS to replace a newer installed ZFS module with an
older package version. Check what APT will select first:
```
apt-cache policy zfs-dkms zfsutils-linux zfs-initramfs libzfs6linux libzpool6linux
sudo apt-get -s install --reinstall zfs-dkms zfsutils-linux zfs-initramfs zfs-zed libzfs6linux libzpool6linux
```

Proceed only if the simulation moves the ZFS packages to one consistent version
and does not downgrade them. After the upgrade, rebuild the initramfs for the
kernel that will boot:
```
sudo dkms autoinstall -k "$(uname -r)"
sudo update-initramfs -u -k "$(uname -r)"
lsinitramfs "/boot/initrd.img-$(uname -r)" | grep 'zfs.ko'
```

It is important to have packages and sources in correct version, for current system.
