# home-manager for hutao — deliberately thin.
#
# This exists for exactly one reason: caelestia ships its shell as a
# home-manager module and there is no NixOS-level equivalent. Everything
# else in ~/.config keeps coming from stow, unchanged.
#
# Stylix's home-manager targets come along for free — the NixOS module
# detects home-manager and wires them itself, so kitty/GTK/Qt now get the
# hu-tao palette too, not just SDDM and the console.
{ inputs, config, ... }:
{
  imports = [
    # Verify the attribute with:  nix flake show github:caelestia-dots/shell
    inputs.caelestia-shell.homeManagerModules.default
  ];

  home.stateVersion = "26.05";

  programs.caelestia = {
    enable = true;
    cli.enable = true;

    # Started from Hyprland via your stowed config, exactly as on Arch.
    # Flip to true to let systemd own it against graphical-session.target —
    # but then remove the exec-once from hyprland.conf or it double-starts.
    systemd.enable = false;

    # Left empty on purpose. Upstream warns that "options or their default
    # values may change across updates, resulting in a stale config", and
    # your ~/.config/caelestia/shell.json already comes from stow. One owner
    # for that file, and it stays stow. Move settings in here later if you'd
    # rather have them declarative.
    settings = { };
  };

  # The hu-tao scheme, so `caelestia scheme set -n hu-tao` resolves.
  #
  # Your caelestia/install.sh sudo-copied this into the Python package's own
  # data directory. That cannot work here — /nix/store is read-only — so it
  # goes to the user config dir instead.
  #
  # VERIFY THIS PATH on first boot: if `caelestia scheme list` doesn't show
  # hu-tao, check where the CLI actually looks and adjust.
  xdg.configFile."caelestia/schemes/hu-tao/default/dark.txt".source =
    ../schemes/hu-tao-dark.txt;
}
