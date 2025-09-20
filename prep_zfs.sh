#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: ./prep_zfs.sh <POOL> [heavy]
# Example:
#   ./prep_zfs.sh rpool_prod
#   ./prep_zfs.sh rpool_prod heavy

POOL="${1:-}"
MODE="${2:-fast}"   # "fast" (default) or "heavy"

if [[ -z "${POOL}" ]]; then
  echo "Usage: $0 <POOL> [heavy]"
  exit 1
fi

if ! command -v zfs >/dev/null 2>&1 || ! command -v zpool >/dev/null 2>&1; then
  echo "ERROR: zfs/zpool commands not found."
  exit 1
fi

if ! zpool list -H -o name | grep -qx "${POOL}"; then
  echo "ERROR: pool '${POOL}' not found."
  exit 1
fi

# Helpers
dataset_exists() { zfs list -H -o name "$1" >/dev/null 2>&1; }
create_ds_if_missing() {
  local ds="$1"; shift
  if dataset_exists "${ds}"; then
    echo "Exists: ${ds} (skipping create)"
  else
    echo "Create: ${ds}"
    zfs create "$@" "${ds}"
  fi
}
set_prop() {
  local ds="$1" prop="$2" val="$3"
  echo "  set ${prop}=${val} on ${ds}"
  zfs set "${prop}=${val}" "${ds}"
}
inherit_prop() {
  local ds="$1" prop="$2"
  echo "  inherit ${prop} on ${ds}"
  zfs inherit "${prop}" "${ds}" || true
}

# Compression policy
# fast  : pool=lz4,  /home=zstd-1, /var/log=zstd-1, /tmp=lz4
# heavy : pool=zstd-1, /home=zstd-3, /var/log=zstd-3, /tmp=lz4
POOL_COMP="lz4"
HOME_COMP="zstd-1"
LOG_COMP="zstd-1"
TMP_COMP="lz4"
if [[ "${MODE}" == "heavy" ]]; then
  POOL_COMP="zstd-1"
  HOME_COMP="zstd-3"
  LOG_COMP="zstd-3"
fi

echo "==> Pool-wide defaults on ${POOL} (inherit first)"
set_prop "${POOL}" atime "off"
set_prop "${POOL}" compression "${POOL_COMP}"

# Dataset paths
ROOT_CONTAINER="${POOL}/ROOT"
ROOT_DATASET="${POOL}/ROOT/debian"
HOME_DS="${POOL}/home"
VAR_DS="${POOL}/var"
LOG_DS="${POOL}/var/log"
TMP_DS="${POOL}/tmp"

echo "==> Create datasets (idempotent, canmount=noauto everywhere)"
create_ds_if_missing "${ROOT_CONTAINER}" -o mountpoint=none -o canmount=off
create_ds_if_missing "${ROOT_DATASET}"  -o mountpoint=/ -o canmount=noauto
create_ds_if_missing "${HOME_DS}"       -o mountpoint=/home -o canmount=noauto
create_ds_if_missing "${VAR_DS}"        -o mountpoint=/var  -o canmount=noauto
create_ds_if_missing "${LOG_DS}"        -o mountpoint=/var/log -o canmount=noauto
create_ds_if_missing "${TMP_DS}"        -o mountpoint=/tmp  -o canmount=noauto

echo "==> Apply properties (no automount)"
# ROOT container (no direct mount)
set_prop "${ROOT_CONTAINER}" mountpoint "none"
set_prop "${ROOT_CONTAINER}" canmount "off"

# Root filesystem
inherit_prop "${ROOT_DATASET}" compression
set_prop     "${ROOT_DATASET}" atime "off"
set_prop     "${ROOT_DATASET}" canmount "noauto"
set_prop     "${ROOT_DATASET}" exec "on"
set_prop     "${ROOT_DATASET}" setuid "on"

# /home
set_prop     "${HOME_DS}" compression "${HOME_COMP}"
set_prop     "${HOME_DS}" atime "off"
set_prop     "${HOME_DS}" canmount "noauto"
set_prop     "${HOME_DS}" exec "on"
set_prop     "${HOME_DS}" setuid "on"

# /var
inherit_prop "${VAR_DS}" compression
set_prop     "${VAR_DS}" atime "off"
set_prop     "${VAR_DS}" canmount "noauto"
set_prop     "${VAR_DS}" exec "on"
set_prop     "${VAR_DS}" setuid "on"

# /var/log (hardened)
set_prop     "${LOG_DS}" compression "${LOG_COMP}"
set_prop     "${LOG_DS}" atime "off"
set_prop     "${LOG_DS}" canmount "noauto"
set_prop     "${LOG_DS}" exec "off"
set_prop     "${LOG_DS}" setuid "off"

# /tmp (hardened; sticky to be handled when actually mounted)
set_prop     "${TMP_DS}" compression "${TMP_COMP}"
set_prop     "${TMP_DS}" atime "off"
set_prop     "${TMP_DS}" canmount "noauto"
set_prop     "${TMP_DS}" exec "on"      # change to off if you want stricter policy
set_prop     "${TMP_DS}" setuid "off"

echo "==> Done (no datasets auto-mounted)."
echo
echo "Summary (datasets):"
zfs list -r "${POOL}" || true
echo
echo "Key props:"
zfs get -r mountpoint,canmount,compression,atime,exec,setuid "${POOL}"

