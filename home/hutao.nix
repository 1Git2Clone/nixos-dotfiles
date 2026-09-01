# home-manager for hutao — deliberately thin.
#
# Two things live here and nothing else: caelestia, because it ships its shell
# as a home-manager module with no NixOS equivalent, and the neovim config,
# because it is the one part of ~/.config worth pinning rather than stowing.
# Everything else keeps coming from stow, unchanged.
#
# Stylix's home-manager targets come along for free — the NixOS module detects
# home-manager and wires them itself, so kitty/GTK/Qt get the hu-tao palette
# too, not just SDDM and the console.
{ inputs, ... }:
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

  # ── neovim ────────────────────────────────────────────────────────────────
  # github:1Git2Clone/nvim-config, pinned as a flake input. This replaces that
  # repo's stow_setup.sh — it is the same tree, placed by Nix instead.
  #
  # THE TRADEOFF, because it will surprise you the first time:
  # /nix/store is read-only, so ~/.config/nvim is a read-only symlink. Plugins
  # still install fine (they go to ~/.local/share/nvim, which is writable), but
  # `:Lazy update` cannot write lazy-lock.json back. The lockfile is pinned by
  # the flake instead, so the way to move plugins is:
  #
  #   nix flake update nvim-config && sudo nixos-rebuild switch --flake .#hutao-laptop
  #
  # That is the reproducible trade and it is why it is the default: a fresh
  # install gets your editor with no extra clone and no stow step.
  #
  # If you would rather hack on the config in place, clone it and swap the line
  # below for an out-of-store symlink, which home-manager will happily manage:
  #
  #   xdg.configFile."nvim".source =
  #     config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nvim-config/nvim";
  #
  # That needs `config` back in the function arguments, and the clone must
  # exist or the session starts with no editor config at all.
  xdg.configFile."nvim".source = "${inputs.nvim-config}/nvim";

  # The hu-tao scheme, so `caelestia scheme set -n hu-tao` resolves.
  #
  # Your caelestia/install.sh sudo-copied this into the Python package's own
  # data directory. That cannot work here — /nix/store is read-only — so it
  # goes to the user config dir instead.
  #
  # VERIFY THIS PATH on first boot: if `caelestia scheme list` doesn't show
  # hu-tao, check where the CLI actually looks and adjust.
  xdg.configFile."caelestia/schemes/hu-tao/default/dark.txt".source = ../schemes/hu-tao-dark.txt;
}
