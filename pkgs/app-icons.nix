# Icons for the hand-written entries in ~/.local/share/applications.
#
# A package rather than home.file: they land in the system hicolor beside every
# other app's icon, which already has an index.theme. A user-level hicolor with
# no index.theme of its own is skipped by icon lookup.
{
  lib,
  runCommandLocal,
}:
runCommandLocal "hutao-app-icons"
  {
    meta = {
      description = "Icons for the umu-run launcher entries";
      license = lib.licenses.gpl3Plus; # seeded from papirus
      platforms = lib.platforms.linux;
    };
  }
  ''
    dir="$out/share/icons/hicolor/scalable/apps"
    mkdir -p "$dir"
    for f in ${../assets/app-icons}/*.svg; do
      cp "$f" "$dir/$(basename "$f")"
    done
    test -n "$(ls "$dir")"
  ''
