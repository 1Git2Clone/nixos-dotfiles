# A package, not a stowed directory, so SDDM and Stylix see it before
# ~/dotfiles exists.
#
# cp -r, not symlinks: the 77 hex-named entries in cursors/ are name-hash
# aliases X11 resolves, and GTK breaks without them.
{
  lib,
  runCommandLocal,
}:
runCommandLocal "hutao-cursor"
  {
    # No license attr: fan art with no stated terms. Marking it unfree would
    # only break `nix build` outside an allowUnfree config.
    meta = {
      description = "Genshin Impact Hu Tao X11 cursor theme";
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
