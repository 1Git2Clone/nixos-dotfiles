# Vendored greeter theme — see assets/sddm-hu-tao/ORIGIN.md.
#
# "sddm-hu-tao" must match the directory name, metadata.desktop's Theme-Id and
# sddm.theme. Main.qml's Qt imports go in sddm.extraPackages, not here.
{
  lib,
  runCommandLocal,
  palette,
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

    # The Colors block was retuned to the scheme by hand in 47c7f5e; these
    # are the same eight values read off it instead, so the greeter follows a
    # retune like everything else. The vendored literal is the placeholder --
    # --replace-fail means a vendor bump that recolours or renames a key
    # fails the build rather than shipping a login screen off the palette.
    substituteInPlace "$dir/$conf" \
      --replace-fail '#EB6C6C' '${palette.hex.primary}' \
      --replace-fail '#f7e6e0' '${palette.hex.rosewater}' \
      --replace-fail '#130a0c' '${palette.hex.base}' \
      --replace-fail '#e5e1e7' '${palette.hex.text}' \
      --replace-fail '#2a1a1e' '${palette.hex.surface1}' \
      --replace-fail '#1e1215' '${palette.hex.surface0}' \
      --replace-fail '#6e4a52' '${palette.hex.overlay2}' \
      --replace-fail '#ff6b69' '${palette.hex.red}'
  ''
