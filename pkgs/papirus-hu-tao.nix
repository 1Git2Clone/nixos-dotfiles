# Papirus-Dark with a sane missing-icon fallback.
#
# caelestia hardcodes "image-missing" as the launcher's fallback
# (modules/launcher/items/AppItem.qml), and Papirus draws that as a magenta
# broken-image glyph. Overriding the icon is the only lever: the fallback name
# is not configurable.
#
# One scalable directory, so a single SVG answers every requested size. Inherits
# do the rest — this theme contains exactly one icon.
{
  lib,
  runCommandLocal,
  papirus-icon-theme,
}:
runCommandLocal "papirus-hu-tao"
  {
    meta = {
      description = "Papirus-Dark with application-default-icon as the missing-icon fallback";
      inherit (papirus-icon-theme.meta) license;
      platforms = lib.platforms.linux;
    };
  }
  ''
    base=${papirus-icon-theme}/share/icons/Papirus-Dark
    dir="$out/share/icons/Papirus-Hu-Tao/scalable/status"
    mkdir -p "$dir"

    # Follow the symlink: Papirus-Dark's size dirs point into ../Papirus.
    cp -L "$base/64x64/apps/application-default-icon.svg" "$dir/image-missing.svg"

    cat > "$out/share/icons/Papirus-Hu-Tao/index.theme" <<'EOF'
    [Icon Theme]
    Name=Papirus-Hu-Tao
    Comment=Papirus-Dark, minus the magenta broken-image glyph
    Inherits=Papirus-Dark,breeze-dark,hicolor
    Directories=scalable/status

    [scalable/status]
    Context=Status
    Type=Scalable
    Size=48
    MinSize=8
    MaxSize=512
    EOF

    # An unindented heredoc would silently produce a theme no loader accepts.
    sed -i 's/^    //' "$out/share/icons/Papirus-Hu-Tao/index.theme"
  ''
