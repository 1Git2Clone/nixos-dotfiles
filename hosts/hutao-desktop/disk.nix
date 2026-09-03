# Written by hand from the live machine. install.sh rewrites `device` to the disk
# you select, but asks first when this file already names a different one.
{
  # Stable path. NEVER use /dev/nvme0n1 here: kernel enumeration order can
  # change between boots and disko would happily wipe the wrong disk.
  device = "/dev/disk/by-id/nvme-Micron_MTFDKCD512QGN-1BN1AABLA_24384B21C999";

  # 16GB RAM on a 512GB NVMe. swap >= RAM is the hibernation requirement.
  swapSize = "20G";
  rootSize = "120G";

  # The 2TB HDD. disko never touches it — it holds Windows-side data and
  # backups, so it is only mounted. Change these two lines to move or rename
  # the mount; `lsblk -o NAME,UUID,FSTYPE` gives you the UUID.
  hddUuid = "E464BEF164BEC618";
  hddMount = "/mnt/hdd";
}
