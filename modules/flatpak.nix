# Sober, which VinegarHQ ships as a Flatpak and nothing else -- nixpkgs'
# `vinegar` is the Roblox Studio bootstrapper, a different program -- and
# RustDesk, which nixpkgs has but cache.nixos.org does not build for the
# pinned nixpkgs.
#
# nix-flatpak rather than a `flatpak install` run by hand: the app list stays
# in the repo, and an activation service reconciles it. Not in hosts/common's
# desktop layer, because that activation reaches the network and hutao-vm is
# what CI evaluates.
#
# Flatpaks reach the host's portals, which is what modules/desktop's
# xdg.portal and the hyprland session target in autostart.lua provide. Without
# that a Flatpak has no file picker and no screencast.
{ inputs, ... }:
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  services.flatpak = {
    enable = true;

    # Flathub is nix-flatpak's default remote, so only the app is named here.
    #
    # RustDesk is here rather than in home.packages because nixpkgs' build is
    # not on cache.nixos.org for the nixpkgs this flake pins -- installing it
    # that way means compiling rustdesk and gtk bindings locally on every
    # bump. Flathub ships a binary.
    packages = [
      "org.vinegarhq.Sober"
      "com.rustdesk.RustDesk"
    ];

    # Left false: it would remove anything installed by hand, and a Flatpak
    # installed to try something out should not vanish on the next rebuild.
    uninstallUnmanaged = false;

    # What Sober prints on first run as a `flatpak override --user` to paste.
    # Declared instead, so it survives a reinstall: Discord's rich presence
    # needs the IPC socket, which the sandbox does not hand over by default.
    # Written to /var/lib/flatpak/overrides, so it applies to every user
    # rather than only the one who ran the command. List entries merge with
    # anything applied externally.
    overrides."org.vinegarhq.Sober".Context.filesystems = [
      "xdg-run/app/com.discordapp.Discord:create"
      "xdg-run/discord-ipc-0"
    ];
  };
}
