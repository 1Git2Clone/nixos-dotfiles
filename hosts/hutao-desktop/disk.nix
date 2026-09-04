# Consumed by modules/disk-layout.nix. install.sh rewrites `device`, asking
# first when this file already names a different disk.
{
  # by-id, never /dev/nvme0n1: enumeration order is not stable and disko wipes
  # whatever this names.
  device = "/dev/disk/by-id/nvme-TS512GMTE220S_G023790001";

  # swap >= RAM, for hibernation.
  swapSize = "20G";
  rootSize = "120G";

  # by-id here too: disko wipes whatever this names.
  hddDevice = "/dev/disk/by-id/ata-ST2000DM008-2FR102_WFL43NWP";
  hddMount = "/mnt/hdd";
}
