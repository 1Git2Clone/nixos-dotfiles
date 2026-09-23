# Every cursor theme, by directory name. A directory with a cursors/ in it is a
# theme; anything else there is left alone.
#
# Two sources, because whose artwork it is decides where it lives: ours at the
# top of assets/, and everyone else's in the third-party-assets input -- a
# separate private repo precisely because those packs may not be redistributed.
# A theme is still named after its own directory either way, so a pack moving
# between the two changes nothing but where it is read from.
#
# This is what makes adding a pointer a matter of dropping a folder: nothing
# names a theme twice, so there is no list to forget to update. Picking which
# one the system uses is one line in modules/desktop/cursor.nix.
{
  lib,
  callPackage,
  thirdParty,
}:
let
  roots = builtins.filter builtins.pathExists [
    ../assets
    thirdParty
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
