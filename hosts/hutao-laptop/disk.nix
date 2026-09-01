# Written by install.sh from your answers. Committed so the layout is
# reproducible — this is the only file that knows about physical hardware.
{
  # Stable path. NEVER use /dev/nvme0n1 here: kernel enumeration order can
  # change between boots and disko would happily wipe the wrong disk.
  device = "/dev/disk/by-id/REPLACE_ME";

  # Sized for 8GB soldered RAM. swap >= RAM is the hibernation requirement;
  # 12G gives headroom without burning a quarter of a 256GB disk.
  swapSize = "12G";
  rootSize = "90G";
}
