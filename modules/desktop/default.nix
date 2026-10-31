# Hyprland + SDDM + Stylix, and the system side of what the dotfiles need.
# The binaries themselves are home/'s home.packages, and so is ~/.config.
#
# One file per service here; ./ is imported whole, so a new one needs no edit
# to this list. `palette` is passed down rather than re-imported per file --
# it is the single scheme every themed service reads.
#
# Hyprland and HyprCapture use a shared pinned input (hyprland.nix).
{ lib, inputs, ... }:
{
  imports = import ../../lib/auto.nix { inherit lib; } ./.;

  _module.args.palette = import ../../palette.nix { inherit lib inputs; };
}
