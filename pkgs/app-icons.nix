# Into hicolor, because QIcon falls back to it alone when no Qt platform
# theme is loaded — anything relying on the icon theme renders as Papirus'
# magenta image-missing. This is the set that actually breaks.
#
# Drop a file in assets/app-icons/ to add or replace one.
{
  lib,
  runCommandLocal,
  papirus-icon-theme,
}:
let
  fromPapirus = [
    "preferences-desktop-theme" # qt5ct + qt6ct
    "spotify-client"
    "input-keyboard" # fcitx5 keyboard input viewer
    "enteauth"
    "application-x-executable"
    "applications-system-symbolic"
    "mark-location-symbolic"
  ];
in
runCommandLocal "hutao-app-icons"
  {
    meta = {
      description = "hicolor icons for apps that would otherwise need a themed lookup";
      license = lib.licenses.gpl3Plus; # papirus
      platforms = lib.platforms.linux;
    };
  }
  ''
    dir="$out/share/icons/hicolor/scalable/apps"
    mkdir -p "$dir"

    for f in ${../assets/app-icons}/*.svg; do
      cp "$f" "$dir/$(basename "$f")"
    done

    base=${papirus-icon-theme}/share/icons/Papirus-Dark
    for n in ${lib.concatStringsSep " " fromPapirus}; do
      # First match wins; Papirus files the same name under apps, categories
      # and status depending on the icon.
      src=$(find -L "$base" -name "$n.svg" -print -quit)
      # Fail loudly: a silent miss here is an icon that stays broken.
      test -n "$src" || { echo "no Papirus icon named $n"; exit 1; }
      cp "$src" "$dir/$n.svg"
    done

    test "$(ls "$dir" | wc -l)" -ge ${toString (builtins.length fromPapirus)}
  ''
