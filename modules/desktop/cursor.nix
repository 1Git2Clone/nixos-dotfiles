# Named once; stylix, the greeter and weston each read it back.
#
# Switching pointers is the one line below. A theme is any directory under
# assets/ with a cursors/ in it -- Windows pack or XCursor, pkgs/cursors.nix
# finds it and names it after its own folder -- so adding one is dropping a
# folder in and changing this string.
{ pkgs, ... }:
let
  name = "Hutao-Cursor";

  package = (pkgs.callPackage ../../pkgs/cursors.nix { }).${name};
in
{
  _module.args.cursor = {
    inherit package name;
    size = 24;
  };
}
