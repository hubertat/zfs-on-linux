# Recommended ZFS Compression Settings by CPU

| Dataset   | RPi 4 (Cortex-A72) | RPi 5 (Cortex-A76) | Intel N97 (Alder Lake-N) | Celeron N3450 (Apollo Lake) | Notes |
|-----------|--------------------|--------------------|--------------------------|-----------------------------|-------|
| `/`       | **lz4**            | **zstd-1**         | **zstd-1**               | **lz4**                     | Root FS → lowest latency. Weak CPUs safer with lz4. |
| `/home`   | **zstd-1**         | **zstd-1**         | **zstd-3** (safe)        | **zstd-1**                  | User files; better ratio with zstd, latency less critical. |
| `/var`    | **lz4**            | **zstd-1**         | **zstd-1**               | **lz4**                     | DBs, caches; latency matters more on weak CPUs. |
| `/var/log`| **zstd-1**         | **zstd-1**         | **zstd-3**               | **zstd-1**                  | Text-heavy; great compression with zstd. |
| `/tmp`    | **lz4** (or off)   | **lz4** (or off)   | **lz4** (or off)         | **lz4** (or off)            | Junk files; compression rarely helps. Consider tmpfs. |


