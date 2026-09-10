# A package, not a stowed directory, so SDDM and Stylix see it without a
# user profile in play -- the greeter runs as `sddm` and never reads ~.
#
# cp -r, not symlinks: the 77 hex-named entries in cursors/ are name-hash
# aliases X11 resolves, and GTK breaks without them.
{
  lib,
  runCommandLocal,
}:
runCommandLocal "hutao-cursor"
  {
    # EbiEbiBeam's artwork, free on Ko-fi but not to be redistributed: these
    # files cannot be published. No license attr, so allowUnfree is not needed.
    meta = {
      description = "Genshin Impact Hu Tao X11 cursor theme by EbiEbiBeam";
      homepage = "https://ko-fi.com/s/52f093af4c";
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p "$out/share/icons"
    cp -r ${../assets/Hutao-Cursor} "$out/share/icons/Hutao-Cursor"
    chmod -R u+w "$out/share/icons/Hutao-Cursor"
    # Without index.theme every loader silently ignores the theme.
    test -f "$out/share/icons/Hutao-Cursor/index.theme"
  ''
