# Recommended ZFS options

## Compression Settings by CPU

| Dataset   | RPi 4 (Cortex-A72) | RPi 5 (Cortex-A76) | Intel N97 (Alder Lake-N) | Celeron N3450 (Apollo Lake) | Notes |
|-----------|--------------------|--------------------|--------------------------|-----------------------------|-------|
| `/`       | **lz4**            | **zstd-1**         | **zstd-1**               | **lz4**                     | Root FS → lowest latency. Weak CPUs safer with lz4. |
| `/home`   | **zstd-1**         | **zstd-1**         | **zstd-3** (safe)        | **zstd-1**                  | User files; better ratio with zstd, latency less critical. |
| `/var`    | **lz4**            | **zstd-1**         | **zstd-1**               | **lz4**                     | DBs, caches; latency matters more on weak CPUs. |
| `/var/log`| **zstd-1**         | **zstd-1**         | **zstd-3**               | **zstd-1**                  | Text-heavy; great compression with zstd. |
| `/tmp`    | **lz4** (or off)   | **lz4** (or off)   | **lz4** (or off)         | **lz4** (or off)            | Junk files; compression rarely helps. Consider tmpfs. |


## Dataset options for media
Big files, already compressed, so no compression (or least cpu intensive) and some other suggested options.

```bash
# Create dataset optimized for large sequential files
sudo zfs create -o compression=lz4 -o recordsize=1M -o atime=off -o logbias=throughput -o primarycache=metadata -o xattr=sa -o mountpoint=/media pool-name-here

# If CPU is extremely constrained and files are already compressed:
# zfs set compression=off tank/media
```

## Property chooser — quick guidance

- **compression**
  - `zstd-3`: great default — better ratio than lz4 with modest CPU use; ideal for text, office docs, RAW photos.
  - `lz4`: ultra-fast, minimal CPU; good “safe default” and for media (auto-aborts on incompressible data).
  - `off`: use only for fully pre-compressed large files on very weak CPUs.

- **recordsize**
  - Small writes (logs, DBs): `16K` (or match app page size if known).
  - Default/mixed: `128K`.
  - Big sequential media: `1M` (OpenZFS supports up to 1M).

- **atime**
  - Use `off` almost everywhere to avoid extra writes.

- **logbias**
  - `latency`: small sync-heavy workloads (logs, DBs).
  - `throughput`: large sequential workloads (media).

- **primarycache / secondarycache**
  - Media servers: `primarycache=metadata` so streaming doesn’t evict hot small files from ARC.
  - General workloads: leave `primarycache=all`.
  - With L2ARC: consider `secondarycache=metadata` for media datasets.

- **xattr**
  - `xattr=sa` keeps extended attributes in the inode — faster access.

- **sync**
  - Keep `sync=standard`.
    Only change if you fully understand the risk (`sync=disabled` can lose recent writes on power loss).

- **dedup**
  - Keep `off` unless a proven win (VM image farms, etc.) and ample RAM.

- **copies**
  - `copies=2` for extra safety on small, critical logs (doubles on-disk size).
