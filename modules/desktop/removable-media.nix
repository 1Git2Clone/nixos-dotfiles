# Nautilus lists removable drives through the gvfs udisks2 volume monitor;
# without both, a plugged-in stick never reaches the sidebar.
#
# Mounting needs no extra work: ntfs3g is in packages.nix, so udisks2 hands
# NTFS sticks off to it.
{
  services.udisks2.enable = true;
  services.gvfs.enable = true;
}
