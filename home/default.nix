# One user's whole home, as one file per app. ./apps is imported whole, so a
# new app is a new file there and nothing else -- no list to keep in sync.
#
# `palette` is passed down rather than re-imported per file; `dotfiles` is the
# patched ~/.config derivation, published by apps/dotfiles.nix for the few
# apps that read a path out of it.
{ inputs, lib, ... }:
{
  imports = [
    inputs.caelestia-shell.homeManagerModules.default
  ]
  ++ import ../lib/auto.nix { inherit lib; } ./apps;

  _module.args.palette = import ../palette.nix { inherit lib; };

  home.stateVersion = "26.05";
}
