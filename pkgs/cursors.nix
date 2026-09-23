# Every cursor theme in assets/, by directory name. A directory with a cursors/
# in it is a theme; anything else there is left alone.
#
# Two roots, because whose artwork it is decides where it sits: ours at the top
# of assets/, and someone else's under assets/third-party/, where it can carry
# its own terms -- free to use, not to redistribute. A theme is still named
# after its own directory either way, so moving one between the two changes
# nothing but the folder it is read from.
#
# This is what makes adding a pointer a matter of dropping a folder: nothing
# names a theme twice, so there is no list to forget to update. Picking which
# one the system uses is one line in modules/desktop/cursor.nix.
{ lib, callPackage }:
let
  roots = builtins.filter builtins.pathExists [
    ../assets
    ../assets/third-party
  ];

  themesIn =
    root:
    lib.mapAttrs (name: _: root + "/${name}") (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (root + "/${name}/cursors")
      ) (builtins.readDir root)
    );
in
lib.mapAttrs (name: src: callPackage ./cursor-theme.nix { } { inherit name src; }) (
  lib.foldl' (acc: root: acc // themesIn root) { } roots
)
