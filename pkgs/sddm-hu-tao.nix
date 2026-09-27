# Vendored greeter theme — see assets/sddm-hu-tao/ORIGIN.md.
#
# The name must match the directory, metadata.desktop's Theme-Id and
# sddm.theme, so it is bound once and read back off passthru rather than
# repeated at each of those. Main.qml's Qt imports go in sddm.extraPackages,
# not here.
{
  lib,
  runCommandLocal,
  palette,
  background,
}:
let
  name = "sddm-hu-tao";
  src = ../assets/sddm-hu-tao;
in
runCommandLocal name
  {
    # So services.displayManager.sddm.theme can name this without repeating
    # the string.
    passthru.themeName = name;

    meta = {
      description = "SDDM greeter: sddm-astronaut's pixel_sakura, re-backgrounded";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.linux;
    };
  }
  ''
    dir="$out/share/sddm/themes/${name}"
    mkdir -p "$dir"
    cp -r ${src}/. "$dir"/
    chmod -R u+w "$dir"
    rm -f "$dir/ORIGIN.md"

    # A missing file here presents as "the theme did not apply": SDDM falls
    # back to its default silently.
    test -f "$dir/metadata.desktop"
    test -f "$dir/Main.qml"
    conf=$(sed -n 's/^ConfigFile=//p' "$dir/metadata.desktop")
    test -f "$dir/$conf"

    # The background is caelestia's wallpaper (stylix.image), fan art from
    # the private third-party-assets input, in place of the vendored one.
    wall="${background}"
    mkdir -p "$dir/Backgrounds"
    cp "$wall" "$dir/Backgrounds/wallpaper.''${wall##*.}"
    substituteInPlace "$dir/$conf" \
      --replace-fail 'Background="Backgrounds/hu-tao.png"' \
        "Background=\"Backgrounds/wallpaper.''${wall##*.}\""
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
