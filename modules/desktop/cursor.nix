# Named once; stylix, the greeter and weston each read it back.
{ pkgs, ... }:
let
  package = pkgs.callPackage ../../pkgs/hutao-cursor.nix { };
in
{
  _module.args.cursor = {
    inherit package;
    name = package.themeName;
    size = 24;
  };
}
