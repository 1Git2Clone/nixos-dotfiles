# Hutao-Cursor as a package rather than a stowed directory, so SDDM and Stylix
# can see it before ~/dotfiles exists.
#
# The 77 hex-named entries in cursors/ are symlinks to the 17 real files; X11
# looks cursors up by name hash and GTK apps break without them. Keep cp -r.
{
  lib,
  runCommandLocal,
}:
runCommandLocal "hutao-cursor"
  {
    # No license: fan art with no stated terms, and nixpkgs treats absent as
    # unrestricted. Marking it unfree only breaks `nix build` outside a config
    # with allowUnfree.
    meta = {
      description = "Genshin Impact Hu Tao X11 cursor theme";
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p "$out/share/icons"
    cp -r ${../assets/Hutao-Cursor} "$out/share/icons/Hutao-Cursor"
    chmod -R u+w "$out/share/icons/Hutao-Cursor"
    # A theme with no index.theme is silently ignored by every loader.
    test -f "$out/share/icons/Hutao-Cursor/index.theme"
  ''
