# install zfs on raspberry pi

From [https://forums.raspberrypi.com/viewtopic.php?t=334421]:


*The below procedure always has worked for me on RPi 3's and 4's*

```
sudo apt update
sudo apt install raspberrypi-kernel-headers zfs-dkms zfsutils-linux -y
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

# install zfs on debian (general, intel/amd)

From [https://wiki.debian.org/ZFS] and [https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Buster%20Root%20on%20ZFS.html]

Update apt, remember to add non-free sources, contrib etc.
Install packages:
```
sudo apt update
sudo apt install linux-headers-amd64 zfsutils-linux dpkg-dev linux-image-amd64
sudo apt install zfs-initramfs
```

In case of problems with zfs module, try:
```
sudo dkms autoinstall -k $(uname -r)
```
After this it should work:
```
sudo modprobe zfs
```

It is important to have packages and sources in correct version, for current system.
