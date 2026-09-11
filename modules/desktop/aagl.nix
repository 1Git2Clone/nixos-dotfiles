# An Anime Game Launcher. The upstream README's plain-Nix snippet reaches for
# `fetchTarball`, which a flake cannot do in pure evaluation -- so the tarball
# becomes the `aagl` input in flake.nix, and the module comes off that instead.
# Same two attributes either way: `module` there is `nixosModules.default`
# here, and nixConfig is the cache both ways.
#
# A NixOS module and not home-manager because that is all upstream ships, and
# because the launchers' /etc/hosts rules are system scope by nature.
{ inputs, ... }:
let
  inherit (inputs) aagl;
in
{
  imports = [
    aagl.nixosModules.default
  ];

  nix.settings = aagl.nixConfig; # Set up Cachix
  programs = {
    anime-game-launcher.enable = true;
    # anime-games-launcher.enable = false;
    honkers-railway-launcher.enable = false;
    honkers-launcher.enable = false;
    wavey-launcher.enable = false;
    sleepy-launcher.enable = false;
  };
}
