# grub issues

## incorrect, double entry for root=ZFS

### issue

Having something like:
```
linux   /vmlinuz-6.12.38+deb13-amd64 root=ZFS=/ROOT/debian ro root=ZFS=rpool_hard/ROOT/debian
```
In generated `/boot/grub/grub.cfg' is incorrect.

It is caused by two sources adding `root=..` entry, one cause could be manually adding in `/etc/default/grub` something like:
```
GRUB_CMDLINE_LINUX="root=ZFS=rpool_hard/ROOT/debian"
```

### workaround - WRONG

In script `/etc/grub.d/10_linux` (or similar name) I did:
```
linux   ${rel_dirname}/${basename} ro ${args}
```

WORKAROUND! root= removed from script, it is defined in /etc/defaults/grub, original was:
```
linux   ${rel_dirname}/${basename} root=${linux_root_device_thisversion} ro ${args}
```

And in `/etc/default/grub` this have to be defined:
```
GRUB_CMDLINE_LINUX="root=ZFS=rpool_hard/ROOT/debian"
```

This is not required, all could be made in config, look below.

### workaround GOOD

In `/etc/default/grub` make sure (adjust zpool name):
```
GRUB_CMDLINE_LINUX="root=ZFS=rpool_hard/ROOT/debian"
#GRUB_CMDLINE_LINUX=""
```
This to detecto other OS (eg the one on regular ext4 partition -rescue/helper):
```
GRUB_DISABLE_OS_PROBER=false
```
This to disable adding `root=` because we define it above:
```
GRUB_DISABLE_LINUX_UUID=true
```

And regenerate and check:
```
update-grub
grep -n 'linux\s\+/vmlinuz' /boot/grub/grub.cfg
```

It should be single `root= ` in one line, not multiple.
