# Only what a user profile cannot reach. Everything the keybinds, scripts and
# dotfiles call is home/apps/packages.nix instead -- with useUserPackages that
# lands in /etc/profiles/per-user/hutao, and environment.profiles already puts
# that on PATH, XDG_DATA_DIRS, XCURSOR_PATH and QT_PLUGIN_PATH, so a
# user-profile package is found exactly like a system one.
#
# The greeter's own two packages are in sddm.nix, beside what names them.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # mount resolves its mount.ntfs helper off root's PATH.
    ntfs3g

    # sgdisk and parted. disko's own scripts carry both on their PATH, which
    # is why the script partitions fine and a shell cannot. Run under sudo,
    # so a user profile is the wrong place for them.
    gptfdisk
    parted
  ];
}
