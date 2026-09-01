# Written by install.sh from your answers. Committed so the layout is
# reproducible — this is the only file that knows about physical hardware.
{
  # Stable path. NEVER use /dev/nvme0n1 here: kernel enumeration order can
  # change between boots and disko would happily wipe the wrong disk.
  device = "/dev/disk/by-id/REPLACE_ME";

  # Sized for 16GB RAM on a 512GB disk. swap >= RAM is the hibernation
  # requirement; 20G gives headroom. Leaves ~370G for /home.
  swapSize = "20G";
  rootSize = "120G";
}
