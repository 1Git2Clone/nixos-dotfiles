# The SDDM greeter theme: upstream's pixel_sakura on a hu-tao background.
#
# Vendored rather than taken from pkgs.sddm-astronaut — see
# assets/sddm-hu-tao/ORIGIN.md for the licence, the pinned upstream revision,
# what was dropped and the two lines that differ.
#
# The directory name under share/sddm/themes/ is what
# services.displayManager.sddm.theme matches on, so "sddm-hu-tao" appears in
# three places and they must agree: here, metadata.desktop's Theme-Id, and
# modules/desktop.nix.
#
# This installs files and nothing else. The Qt modules Main.qml imports —
# QtMultimedia, QtQuick.VirtualKeyboard, and qtsvg for the icons in Assets/ —
# have to reach the *greeter*, not this package, so they are declared in
# modules/desktop.nix as sddm.extraPackages.
{
  lib,
  runCommandLocal,
}:
runCommandLocal "sddm-hu-tao"
  {
    meta = {
      description = "SDDM greeter theme: sddm-astronaut's pixel_sakura, re-backgrounded";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.linux;
    };
  }
  ''
    dir="$out/share/sddm/themes/sddm-hu-tao"
    mkdir -p "$dir"
    cp -r ${../assets/sddm-hu-tao}/. "$dir"/
    chmod -R u+w "$dir"

    # ORIGIN.md is repo documentation, not part of the theme.
    rm -f "$dir/ORIGIN.md"

    # SDDM silently falls back to its default theme when metadata.desktop is
    # missing or the ConfigFile it names does not exist, so a typo here would
    # show up as "the theme just did not apply" on a machine you cannot easily
    # inspect. Fail at build time instead.
    test -f "$dir/metadata.desktop"
    test -f "$dir/Main.qml"
    conf=$(sed -n 's/^ConfigFile=//p' "$dir/metadata.desktop")
    test -n "$conf"
    test -f "$dir/$conf"

    # Likewise the background: a missing file renders as a blank colour field,
    # which looks exactly like a theme that loaded but has no wallpaper.
    bg=$(sed -n 's/^Background="\(.*\)"$/\1/p' "$dir/$conf")
    test -n "$bg"
    test -f "$dir/$bg"
  ''
