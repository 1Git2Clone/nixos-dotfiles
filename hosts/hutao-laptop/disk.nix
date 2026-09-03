# Consumed by modules/disk-layout.nix; install.sh rewrites `device`.
{
  # by-id, never /dev/nvme0n1: enumeration order is not stable and disko wipes
  # whatever this names.
  device = "/dev/disk/by-id/nvme-Micron_MTFDKCD512QGN-1BN1AABLA_24384B21C999";

  # swap >= RAM, for hibernation.
  swapSize = "20G";
  rootSize = "120G";
}
