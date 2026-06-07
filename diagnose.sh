#!/usr/bin/env bash
# diagnose.sh — discover the current state of a (prospective) Linux-on-ZFS system.
#
# Read-only. Safe to run on any system. Produces a single Markdown report on
# stdout that is meant to be:
#   1. readable by a human in the terminal, and
#   2. pasted into an LLM chat/agent for troubleshooting help.
#
# Usage:
#   ./diagnose.sh                 # print report to stdout
#   ./diagnose.sh -o report.md    # also save a copy to a file
#   sudo ./diagnose.sh            # fuller results (some checks need root)
#
# Nothing here changes system state. Commands that could require root are run
# anyway and simply report "permission denied / needs sudo" when they fail.

set -uo pipefail

OUT_FILE=""
if [[ "${1:-}" == "-o" && -n "${2:-}" ]]; then
  OUT_FILE="$2"
fi

# ---- output helpers ---------------------------------------------------------
# Everything is written to a temp buffer so we can both print and optionally save.
BUF="$(mktemp)"
trap 'rm -f "$BUF"' EXIT
say()  { printf '%s\n' "$*" >>"$BUF"; }
h1()   { say ""; say "# $*"; say ""; }
h2()   { say ""; say "## $*"; say ""; }
kv()   { say "- **$1:** $2"; }

# have CMD -> "yes (path)" / "no"
have() { command -v "$1" >/dev/null 2>&1; }

# fence: run a command, capture stdout+stderr into a fenced code block.
# Usage: fence "lang" command args...
fence() {
  local lang="$1"; shift
  say '```'"$lang"
  if "$@" >>"$BUF" 2>&1; then :; else
    say "(command failed or unavailable: $* — may need sudo)"
  fi
  say '```'
}

# read_file: dump a file in a fence, or note it's missing.
read_file() {
  local f="$1"
  if [[ -r "$f" ]]; then
    say '```'
    cat "$f" >>"$BUF" 2>&1 || say "(could not read $f)"
    say '```'
  elif [[ -e "$f" ]]; then
    say "_exists but not readable (try sudo): \`$f\`_"
  else
    say "_not present: \`$f\`_"
  fi
}

# ============================================================================
h1 "Linux-on-ZFS system diagnostic"
kv "Generated" "$(date -u '+%Y-%m-%dT%H:%M:%SZ') (UTC)"
kv "Hostname"  "$(hostname 2>/dev/null || echo '?')"
kv "Running as root" "$([[ "$(id -u)" -eq 0 ]] && echo yes || echo 'no (some checks limited)')"
kv "In chroot" "$([[ "$(stat -c %d:%i / 2>/dev/null)" != "$(stat -c %d:%i /proc/1/root/. 2>/dev/null)" ]] && echo 'likely yes' || echo 'no / unknown')"

# ---- 1. Platform -----------------------------------------------------------
h1 "1. Platform & CPU"
ARCH="$(uname -m 2>/dev/null)"
kv "Architecture" "$ARCH"

IS_PI="no"
PI_MODEL=""
if [[ -r /proc/device-tree/model ]]; then
  PI_MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null)"
  [[ "$PI_MODEL" == *Raspberry* ]] && IS_PI="yes"
fi
kv "Raspberry Pi" "$IS_PI${PI_MODEL:+ ($PI_MODEL)}"

CPU_MODEL="$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^ *//')"
[[ -z "$CPU_MODEL" ]] && CPU_MODEL="$(awk -F: '/Model/{print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^ *//')"
kv "CPU model" "${CPU_MODEL:-unknown}"
kv "CPU cores" "$(nproc 2>/dev/null || echo '?')"
kv "Total RAM" "$(awk '/MemTotal/{printf "%.1f GiB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo '?')"
say ""
say "> Compression guidance per CPU lives in \`cpu_vs_compression.md\`."

# ---- 2. OS / kernel --------------------------------------------------------
h1 "2. Operating system & kernel"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  kv "Distro" "${PRETTY_NAME:-$NAME} (${VERSION_CODENAME:-?})"
fi
kv "Kernel" "$(uname -r 2>/dev/null)"
kv "Booted via systemd" "$([[ -d /run/systemd/system ]] && echo yes || echo no)"

# ---- 3. ZFS install state --------------------------------------------------
h1 "3. ZFS installation"
kv "zfs binary"   "$(have zfs   && command -v zfs   || echo 'NOT FOUND')"
kv "zpool binary" "$(have zpool && command -v zpool || echo 'NOT FOUND')"

if have zfs; then
  h2 "zfs version"
  fence "" zfs version
fi

h2 "ZFS kernel module"
if lsmod 2>/dev/null | grep -q '^zfs'; then
  kv "module loaded" "yes"
else
  kv "module loaded" "no (try: sudo modprobe zfs)"
fi

if have dpkg-query; then
  h2 "Installed ZFS-related packages"
  fence "" dpkg-query -W -f='${Package} ${Version} (${Status})\n' \
    'zfs-dkms' 'zfsutils-linux' 'zfs-initramfs' 'zfs-zed' \
    'linux-headers-*' 'raspberrypi-kernel' 'raspberrypi-kernel-headers'
  h2 "DKMS status"
  fence "" dkms status
fi

# ---- 4. Pools & datasets ---------------------------------------------------
h1 "4. Pools & datasets"
if have zpool; then
  h2 "zpool list"
  fence "" zpool list
  h2 "zpool status"
  fence "" zpool status
  h2 "Pool boot-relevant properties (bootfs, cachefile)"
  fence "" zpool get bootfs,cachefile,altroot
fi

if have zfs; then
  h2 "Datasets (zfs list)"
  fence "" zfs list -o name,used,avail,mountpoint,canmount
  h2 "Key dataset properties"
  say "_Project convention: \`POOL/ROOT/debian\` = /, plus home, var, var/log, tmp._"
  fence "" zfs get -o name,property,value mountpoint,canmount,compression,atime,exec,setuid,recordsize
fi

# ---- 5. Is root already on ZFS? -------------------------------------------
h1 "5. Current root filesystem"
if have findmnt; then
  fence "" findmnt -no SOURCE,FSTYPE,TARGET /
else
  fence "" sh -c 'mount | grep " / "'
fi
ROOT_FS="$( (findmnt -no FSTYPE / 2>/dev/null) || true)"
if [[ "$ROOT_FS" == "zfs" ]]; then
  kv "Root on ZFS" "YES — system is already running on ZFS"
else
  kv "Root on ZFS" "no (root fstype: ${ROOT_FS:-unknown}) — install/migration not yet complete"
fi

# ---- 6. Disks / partitions -------------------------------------------------
h1 "6. Block devices"
if have lsblk; then
  fence "" lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,PARTUUID
else
  read_file /proc/partitions
fi

# ---- 7. Boot configuration -------------------------------------------------
h1 "7. Boot configuration"

if [[ "$IS_PI" == "yes" ]]; then
  h2 "Raspberry Pi: cmdline.txt"
  if   [[ -e /boot/firmware/cmdline.txt ]]; then read_file /boot/firmware/cmdline.txt
  else read_file /boot/cmdline.txt; fi
  say "_Expect \`root=ZFS=POOL/ROOT/debian\`, \`rootfstype=zfs\`, \`boot=zfs\` for ZFS root._"

  h2 "Raspberry Pi: config.txt"
  if   [[ -e /boot/firmware/config.txt ]]; then read_file /boot/firmware/config.txt
  else read_file /boot/config.txt; fi
else
  h2 "GRUB: /etc/default/grub"
  read_file /etc/default/grub
  say "_See \`grub_issues.md\`: set GRUB_CMDLINE_LINUX=\"root=ZFS=...\", GRUB_DISABLE_LINUX_UUID=true._"

  h2 "GRUB: duplicate root= check in grub.cfg"
  if [[ -r /boot/grub/grub.cfg ]]; then
    say '```'
    grep -n 'linux\s\+/.*vmlinuz' /boot/grub/grub.cfg >>"$BUF" 2>&1 || say "(no kernel lines found)"
    say '```'
    if grep -E 'linux\s+/.*vmlinuz' /boot/grub/grub.cfg 2>/dev/null | grep -q 'root=.*root='; then
      kv "Duplicate root=" "DETECTED — see grub_issues.md"
    else
      kv "Duplicate root=" "none detected"
    fi
  else
    say "_not readable: /boot/grub/grub.cfg (try sudo)_"
  fi
fi

# ---- 8. initramfs & zfs initrd config -------------------------------------
h1 "8. initramfs / ZFS initrd"
h2 "/etc/initramfs-tools/modules (zfs present?)"
if [[ -r /etc/initramfs-tools/modules ]]; then
  if grep -q '^zfs' /etc/initramfs-tools/modules 2>/dev/null; then
    kv "zfs module listed" "yes"
  else
    kv "zfs module listed" "NO — add: echo zfs | sudo tee -a /etc/initramfs-tools/modules"
  fi
else
  say "_not readable: /etc/initramfs-tools/modules_"
fi

h2 "/etc/default/zfs (double-mount pitfall)"
if [[ -r /etc/default/zfs ]]; then
  if grep -q '^ZFS_INITRD_ADDITIONAL_DATASETS=.*ROOT' /etc/default/zfs 2>/dev/null; then
    kv "ZFS_INITRD_ADDITIONAL_DATASETS" "contains ROOT dataset — likely causes the double-mount-in-initramfs error (see mount_and_chroot.md)"
  else
    kv "ZFS_INITRD_ADDITIONAL_DATASETS" "ok (root dataset not listed)"
  fi
else
  say "_not present/readable: /etc/default/zfs_"
fi

# ---- 9. fstab & apt sources -----------------------------------------------
h1 "9. fstab & apt sources"
h2 "/etc/fstab"
read_file /etc/fstab
say "_Root dataset should NOT be in fstab (ZFS mounts it). /boot, /boot/efi, swap may be._"

h2 "apt sources: contrib / non-free present?"
SRC_HITS="$(grep -REl 'non-free' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || true)"
if [[ -n "$SRC_HITS" ]]; then
  kv "contrib/non-free" "found in: $SRC_HITS"
else
  kv "contrib/non-free" "NOT found — needed for ZFS on Debian (see debian_sources.md)"
fi

# ---- 10. Summary / next-step hints ----------------------------------------
h1 "10. Summary"
say "| Check | State |"
say "|-------|-------|"
say "| Platform | ${IS_PI/yes/Raspberry Pi}${IS_PI/no/x86} ($ARCH) |"
say "| ZFS tools installed | $(have zfs && echo yes || echo NO) |"
say "| ZFS module loaded | $(lsmod 2>/dev/null | grep -q '^zfs' && echo yes || echo no) |"
say "| Pool(s) present | $(have zpool && [[ -n "$(zpool list -H -o name 2>/dev/null)" ]] && echo yes || echo no) |"
say "| Root on ZFS | $([[ "$ROOT_FS" == zfs ]] && echo YES || echo no) |"
say ""
say "_Read-only report. See the project .md files referenced above for fixes._"

# ---- emit ------------------------------------------------------------------
cat "$BUF"
if [[ -n "$OUT_FILE" ]]; then
  cp "$BUF" "$OUT_FILE" && printf '\n[saved report to %s]\n' "$OUT_FILE" >&2
fi
