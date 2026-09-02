# Thin on purpose: caelestia ships only a home-manager module, and neovim is
# worth pinning. Everything else in ~/.config still comes from stow.
{ inputs, ... }:
{
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  home.stateVersion = "26.05";

  programs.caelestia = {
    enable = true;
    cli.enable = true;
    # Started from Hyprland by the stowed config. Flipping this to true means
    # removing the exec-once, or it double-starts.
    systemd.enable = false;
    # Owned by stow (~/.config/caelestia/shell.json). One owner, not two.
    settings = { };
  };

  # /nix/store is read-only, so `:Lazy update` cannot write lazy-lock.json.
  # Plugins still install to ~/.local/share/nvim. To move them:
  #   nix flake update nvim-config && sudo nixos-rebuild switch --flake .#hutao-laptop
  #
  # To hack on it in place instead, clone it and use:
  #   config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nvim-config/nvim"
  xdg.configFile."nvim".source = "${inputs.nvim-config}/nvim";

  # VERIFY on first boot: if `caelestia scheme list` lacks hu-tao, find where
  # the CLI actually looks.
  xdg.configFile."caelestia/schemes/hu-tao/default/dark.txt".source = ../schemes/hu-tao-dark.txt;
}
