# Every cursor theme in assets/, by directory name. A directory with a
# cursors/ in it is a theme; anything else there is left alone.
#
# This is what makes adding a pointer a matter of dropping a folder: nothing
# names a theme twice, so there is no list to forget to update. Picking which
# one the system uses is one line in modules/desktop/cursor.nix.
{ lib, callPackage }:
let
  assets = ../assets;
  isTheme = name: type: type == "directory" && builtins.pathExists (assets + "/${name}/cursors");
in
lib.mapAttrs (
  name: _:
  callPackage ./cursor-theme.nix { } {
    inherit name;
    src = assets + "/${name}";
  }
) (lib.filterAttrs isTheme (builtins.readDir assets))
