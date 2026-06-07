# zfs-on-linux

Personal runbook + helper scripts for installing and troubleshooting **Debian (and Raspberry Pi OS / Raspbian) with the root filesystem on ZFS** — keeping non-ZFS storage to a minimum.

Targets:

1. **Debian** on x86 Intel/AMD platforms
2. **Debian / Raspbian** on Raspberry Pi hardware (tested on Pi 3/4/5)

All `.md` files are written to be both human- and LLM/agent-readable. The `.sh`
files are helper scripts for the repetitive, error-prone steps.

> **Project convention:** the root pool uses the dataset layout
> `POOL/ROOT/debian` = `/`, plus `POOL/home`, `POOL/var`, `POOL/var/log`,
> `POOL/tmp`. The scripts assume this layout. The pool name (`POOL`) is passed
> as an argument; the `ROOT/debian` root-dataset name is currently hardcoded.

---

## Start here: diagnose an existing system

Before (or during) any work, run the read-only discovery script to capture the
current state into a single Markdown report — readable in the terminal and
pasteable into an LLM chat for troubleshooting:

```bash
./diagnose.sh                  # print report
sudo ./diagnose.sh -o report.md   # fuller results + save a copy
```

It reports platform/CPU, ZFS install state, pools & datasets, whether root is
already on ZFS, boot config (GRUB or Pi `cmdline.txt`), the initramfs/`grub`
pitfalls documented below, and a summary table — each finding linked to the
relevant doc.

---

## Recommended order (fresh install / migration to ZFS root)

| # | Step | File(s) |
|---|------|---------|
| 1 | Prep a fresh/minimal Linux (packages, tmux, sudo, terminfo) | [`fresh_linux.md`](fresh_linux.md) |
| 2 | Enable `contrib`/`non-free` apt components (required for ZFS on Debian) | [`debian_sources.md`](debian_sources.md) |
| 3 | Install ZFS (Pi and Debian variants; `modprobe`/DKMS fixes) | [`install_zfs.md`](install_zfs.md) |
| 4 | Create pool datasets with sane properties | [`prep_zfs.sh`](prep_zfs.sh) |
| 5 | Mount datasets under `/mnt/newroot` and chroot in | [`mount_zfs.sh`](mount_zfs.sh), [`mount_and_chroot.sh`](mount_and_chroot.sh), [`mount_and_chroot.md`](mount_and_chroot.md) |
| 6 | Copy the existing system in (rsync) **or** debootstrap fresh | [`mount_and_chroot.md`](mount_and_chroot.md) |
| 7 | Make it boot from ZFS — **x86/GRUB** | [`grub_issues.md`](grub_issues.md), [`mount_and_chroot.md`](mount_and_chroot.md) |
| 7 | Make it boot from ZFS — **Raspberry Pi** | [`mount_and_chroot.md`](mount_and_chroot.md) (§ "Boot into ZFS partition") |
| 8 | Unmount / export cleanly and reboot | [`umount_chroot.sh`](umount_chroot.sh), [`umount_zfs.sh`](umount_zfs.sh) |

### Tuning & operations (reference)

- [`cpu_vs_compression.md`](cpu_vs_compression.md) — per-CPU compression choices and dataset property guidance (recordsize, atime, logbias, primarycache, xattr…).
- [`copy_zpool.md`](copy_zpool.md) — migrate a single-disk pool to a new disk via mirror → detach → expand.
- [`telegraf.md`](telegraf.md) + [`telegraf.conf.rpi.example`](telegraf.conf.rpi.example) — monitoring config examples (Pi CPU/GPU temps).

---

## Helper scripts

All scripts need **root** (run with `sudo`). They take the pool name as the first
argument and assume the `POOL/ROOT/debian` layout above.

| Script | Purpose |
|--------|---------|
| `diagnose.sh` | Read-only system discovery → Markdown report. Safe anywhere. |
| `prep_zfs.sh <POOL> [heavy]` | Create datasets and set properties (idempotent). `heavy` = stronger compression. |
| `mount_zfs.sh <POOL>` | Point the layout's datasets at `/mnt/newroot` and `zfs mount` them. |
| `mount_and_chroot.sh [--copy-dns]` | Bind-mount `/proc /sys /dev /run` into `/mnt/newroot` and `chroot` in. |
| `umount_chroot.sh` | Unmount the chroot's virtual filesystems (lazy). |
| `umount_zfs.sh <POOL>` | Unmount the datasets, reset mountpoints to `/`, and export the pool. |

Typical migration session:

```bash
sudo ./prep_zfs.sh rpool
sudo ./mount_zfs.sh rpool
# ... rsync the system in (see mount_and_chroot.md) ...
sudo ./mount_and_chroot.sh        # do boot/initramfs/grub work inside
# exit the chroot, then:
sudo ./umount_chroot.sh
sudo ./umount_zfs.sh rpool
sudo reboot
```

---

## Known pitfalls (with detectors in `diagnose.sh`)

- **Double `root=` in GRUB** — two sources inject `root=`; fix in `/etc/default/grub`. See [`grub_issues.md`](grub_issues.md).
- **ZFS root mounted twice in initramfs** — caused by `ZFS_INITRD_ADDITIONAL_DATASETS` listing the root dataset in `/etc/default/zfs`. See [`mount_and_chroot.md`](mount_and_chroot.md) § Troubleshooting.
- **No ZFS in initramfs** — ensure `zfs` is in `/etc/initramfs-tools/modules`, then rebuild initramfs.
- **`modprobe zfs` fails after install** — `sudo dkms autoinstall` (see [`install_zfs.md`](install_zfs.md)).
- **Missing `contrib`/`non-free`** — ZFS packages won't be found on Debian (see [`debian_sources.md`](debian_sources.md)).
