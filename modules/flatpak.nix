# Only for Sober, which VinegarHQ ships as a Flatpak and nothing else --
# nixpkgs' `vinegar` is the Roblox Studio bootstrapper, a different program.
#
# nix-flatpak rather than a `flatpak install` run by hand: the app list stays
# in the repo, and an activation service reconciles it. Not in hosts/common's
# desktop layer, because that activation reaches the network and hutao-vm is
# what CI evaluates.
#
# Flatpaks reach the host's portals, which is what modules/desktop.nix's
# xdg.portal and the hyprland session target in autostart.lua provide. Without
# that a Flatpak has no file picker and no screencast.
{ inputs, ... }:
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  services.flatpak = {
    enable = true;

    # Flathub is nix-flatpak's default remote, so only the app is named here.
    packages = [ "org.vinegarhq.Sober" ];

    # Left false: it would remove anything installed by hand, and a Flatpak
    # installed to try something out should not vanish on the next rebuild.
    uninstallUnmanaged = false;
  };
}
