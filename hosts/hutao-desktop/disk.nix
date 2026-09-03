# Consumed by modules/disk-layout.nix. install.sh rewrites `device`, asking
# first when this file already names a different disk.
{
  # by-id, never /dev/nvme0n1: enumeration order is not stable and disko wipes
  # whatever this names.
  device = "/dev/disk/by-id/nvme-TS512GMTE220S_G023790001";

  # swap >= RAM, for hibernation.
  swapSize = "20G";
  rootSize = "120G";

  # Mounted, never partitioned: it holds Windows-side data.
  hddUuid = "E464BEF164BEC618";
  hddMount = "/mnt/hdd";
}
