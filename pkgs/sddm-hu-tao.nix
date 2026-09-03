# Vendored greeter theme — see assets/sddm-hu-tao/ORIGIN.md.
#
# "sddm-hu-tao" must match the directory name, metadata.desktop's Theme-Id and
# sddm.theme. Main.qml's Qt imports go in sddm.extraPackages, not here.
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

    # A missing file here presents as "the theme did not apply": SDDM falls
    # back to its default silently.
    test -f "$dir/metadata.desktop"
    test -f "$dir/Main.qml"
    conf=$(sed -n 's/^ConfigFile=//p' "$dir/metadata.desktop")
    test -f "$dir/$conf"
    bg=$(sed -n 's/^Background="\(.*\)"$/\1/p' "$dir/$conf")
    test -f "$dir/$bg"
  ''
