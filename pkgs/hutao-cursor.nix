# A package, not a stowed directory, so SDDM and Stylix see it without a
# user profile in play -- the greeter runs as `sddm` and never reads ~.
#
# Ships the artwork twice, in one theme directory, because Hyprland and
# everything else read different formats. Hyprland draws every pointer over
# its own surfaces and answers every cursor-shape-v1 request, and it renders
# an XCursor theme by falling back to Adwaita -- so the whole desktop showed a
# plain arrow while slurp, which loads cursors/ itself, was the one place Hu
# Tao appeared. hyprcursors/ is what fixes that.
#
# cp -r, not symlinks: the 77 hex-named entries in cursors/ are name-hash
# aliases X11 resolves, and GTK breaks without them.
{
  lib,
  runCommandLocal,
  hyprcursor,
  xcur2png,
}:
runCommandLocal "hutao-cursor"
  {
    # hyprcursor-util shells out to xcur2png for --extract.
    nativeBuildInputs = [
      hyprcursor
      xcur2png
    ];

    # EbiEbiBeam's artwork, free on Ko-fi but not to be redistributed: these
    # files cannot be published. No license attr, so allowUnfree is not needed.
    meta = {
      description = "Genshin Impact Hu Tao X11 cursor theme by EbiEbiBeam";
      homepage = "https://ko-fi.com/s/52f093af4c";
      platforms = lib.platforms.linux;
    };
  }
  ''
    # The theme name has to match index.theme's Name=, XCURSOR_THEME, and the
    # directory hyprcursor-util derives extracted_/theme_ from -- so it is a
    # variable, not nine literals.
    name=Hutao-Cursor
    src=${../assets/Hutao-Cursor}
    theme="$out/share/icons/$name"

    mkdir -p "$out/share/icons"
    cp -r "$src" "$theme"
    chmod -R u+w "$theme"
    # Without index.theme every loader silently ignores the theme.
    test -f "$theme/index.theme"

    # --extract writes beside its input, so work on a copy. -L, unlike the
    # cp above: dereferencing the aliases gives hyprcursor a real shape per
    # name rather than a dangling override.
    cp -rL "$src" "./$name"
    chmod -R u+w "./$name"
    hyprcursor-util --extract "./$name" >/dev/null

    # hyprcursor takes only [A-Za-z0-9_-.] in a shape directory name and in
    # the image names meta.hl points at, and this pack's masters are
    # "05-Text Select", "13-Diagonal Resize 1" and friends. This rename is
    # what makes the hyprcursor half buildable at all -- substituting each
    # whole filename, ".png" included, since the format uses spaces as
    # separators too.
    for dir in "extracted_$name"/hyprcursors/*/; do
      shape=''${dir%/}
      (
        cd "$shape"
        meta=$(cat meta.hl)
        for img in *.png; do
          case $img in
            *" "*)
              renamed=''${img// /_}
              mv -- "$img" "$renamed"
              meta=''${meta//"$img"/"$renamed"}
              ;;
          esac
        done
        printf '%s\n' "$meta" > meta.hl
      )
      case $shape in
        *" "*) mv -- "$shape" "''${shape// /_}" ;;
      esac
    done

    # The manifest carries the name Hyprland matches on; --extract leaves it
    # as "Extracted Theme".
    sed -i "s/^name = .*/name = $name/" "extracted_$name/manifest.hl"

    hyprcursor-util --create "./extracted_$name" >/dev/null
    cp -r "theme_$name/manifest.hl" "theme_$name/hyprcursors" "$theme/"

    # Both halves have to be there. This bug fails by drawing the wrong
    # cursor, never by erroring, so assert rather than trust.
    test -f "$theme/manifest.hl"
    test -s "$theme/cursors/default"
    test "$(ls "$theme/hyprcursors" | wc -l)" -gt 50
  ''
