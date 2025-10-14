# ZFS Drive Migration (Single Disk → Mirror → Single New Disk)

## Steps Summary

| Step | Command | Description |
|------|----------|-------------|
| 1 | `zpool attach tank /dev/da0 /dev/da1` | Add new disk as mirror |
| 2 | `zpool status tank` | Monitor resilver progress |
| 3 | `zpool detach tank /dev/da0` | Remove old disk after resilver |
| 4 | `zpool online -e tank /dev/da1` | Expand pool to full new disk size |

## Notes

- Make sure the new disk (`/dev/da1`) is empty before attaching.
- After attaching, ZFS will resilver (copy) data automatically.
- You can monitor resilver progress with `zpool status`.
- Once resilvering is complete, detach the old drive.
- The `-e` flag in `zpool online -e` expands the pool to use the full capacity of the new drive.

## Example Workflow

```sh
# Add new disk as mirror
zpool attach tank /dev/da0 /dev/da1

# Monitor resilver progress
zpool status tank

# When finished, remove old drive
zpool detach tank /dev/da0

# Expand pool to full size of new disk
zpool online -e tank /dev/da1

# Verify everything
zpool list
zpool status tank
