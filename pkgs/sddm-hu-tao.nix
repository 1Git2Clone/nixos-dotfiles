# SDDM greeter theme. Vendored — see assets/sddm-hu-tao/ORIGIN.md.
#
# "sddm-hu-tao" must match in three places: this directory name,
# metadata.desktop's Theme-Id, and services.displayManager.sddm.theme.
#
# The Qt modules Main.qml imports must reach the greeter, not this package —
# they are sddm.extraPackages in modules/desktop.nix.
{
  lib,
  runCommandLocal,
}:
runCommandLocal "sddm-hu-tao"
  {
    meta = {
      description = "SDDM greeter: sddm-astronaut's pixel_sakura, re-backgrounded";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.linux;
    };
  }
  ''
    dir="$out/share/sddm/themes/sddm-hu-tao"
    mkdir -p "$dir"
    cp -r ${../assets/sddm-hu-tao}/. "$dir"/
    chmod -R u+w "$dir"
    rm -f "$dir/ORIGIN.md"

    # SDDM falls back to its default silently when any of these is missing,
    # which presents as "the theme did not apply".
    test -f "$dir/metadata.desktop"
    test -f "$dir/Main.qml"
    conf=$(sed -n 's/^ConfigFile=//p' "$dir/metadata.desktop")
    test -f "$dir/$conf"
    bg=$(sed -n 's/^Background="\(.*\)"$/\1/p' "$dir/$conf")
    test -f "$dir/$bg"
  ''
