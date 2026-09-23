# One builder for every cursor theme assets/ holds -- top level, or under
# third-party/ when the artwork is someone else's. A theme is any directory
# there with a cursors/ inside it; pkgs/cursors.nix finds them and names each
# theme after its own directory, so adding one is dropping a folder.
#
# Two input formats, because a pack is either already XCursor or still the
# Windows .ani/.cur it was published as:
#
#   XCursor  -- used as it is. These ship their own name aliases.
#   Windows  -- converted with win2xcur, then given X11 names. A .ani is a
#               RIFF/ACON file: hyprcursor-util cannot read one, which is what
#               "Failed reading xconfig for ...ani" means.
#
# The Windows half reads Installer.inf rather than guessing from filenames.
# Every pack ships one, and its [Strings] section is the author's own map from
# a Windows role to a file -- `pointer = "01-Normal.ani"`. Filenames vary per
# pack; the seventeen role names do not.
#
# Then the theme is written twice into one directory, because Hyprland and
# everything else read different formats. Hyprland answers every
# cursor-shape-v1 request itself and falls back to Adwaita for an XCursor
# theme, so without hyprcursors/ the desktop draws a plain arrow while slurp,
# which loads cursors/ directly, is the one place the theme appears.
{
  lib,
  runCommandLocal,
  hyprcursor,
  xcur2png,
  win2xcur,
}:
{
  name,
  src,
  meta ? { },
}:
runCommandLocal (lib.toLower name)
  {
    # So stylix.cursor.name, the SDDM greeter and weston read this off the
    # package instead of each spelling it out.
    passthru.themeName = name;

    # hyprcursor-util shells out to xcur2png for --extract; win2xcur is only
    # reached for a Windows pack.
    nativeBuildInputs = [
      hyprcursor
      xcur2png
      win2xcur
    ];

    meta = {
      platforms = lib.platforms.linux;
    }
    // meta;
  }
  ''
    name=${name}
    theme="$out/share/icons/$name"

    # Every check below fails the build by design; each says which one it was,
    # because a silent `test` in a builder is a blank log and a guess.
    die() {
      echo "cursor-theme($name): $*" >&2
      exit 1
    }

    # -L: dereferencing an XCursor pack's aliases gives hyprcursor a real
    # shape per name later on rather than a dangling override.
    cp -rL ${src} ./staged
    chmod -R u+w ./staged

    # ── Windows pack ────────────────────────────────────────────────────────
    # find, not a glob: the builder runs with nullglob, so an unmatched
    # `ls cursors/*.ani` is `ls` with no arguments -- it lists the directory
    # and succeeds, and every pack looks like a Windows one.
    winfiles=$(find ./staged/cursors -maxdepth 1 -type f \( -iname '*.ani' -o -iname '*.cur' \))
    if [ -n "$winfiles" ]; then
      inf=$(find ./staged/cursors -maxdepth 1 -type f -iname '*.inf' | head -1)
      [ -n "$inf" ] || die "a Windows pack with no Installer.inf: no role map, and no way to guess one"

      # A Windows role, to every X11 name that means the same pointer. The
      # left column is Installer.inf's vocabulary; the right is what GTK, Qt
      # and cursor-shape-v1 actually ask for. `pin` and `person` are Windows
      # inventions with no X11 name, so they are dropped rather than invented.
      x11names() {
        case $1 in
          pointer)     echo "default left_ptr arrow top_left_arrow" ;;
          help)        echo "help question_arrow whats_this left_ptr_help" ;;
          work)        echo "progress left_ptr_watch half-busy" ;;
          busy)        echo "wait watch" ;;
          cross)       echo "crosshair cross tcross" ;;
          text)        echo "text xterm ibeam" ;;
          hand)        echo "pencil" ;;
          unavailiable | unavailable)
                       echo "not-allowed crossed_circle forbidden no-drop dnd-no-drop" ;;
          vert)        echo "ns-resize sb_v_double_arrow v_double_arrow size_ver" ;;
          horz)        echo "ew-resize sb_h_double_arrow h_double_arrow size_hor" ;;
          dgn1)        echo "nwse-resize size_fdiag bd_double_arrow nw-resize se-resize" ;;
          dgn2)        echo "nesw-resize size_bdiag fd_double_arrow ne-resize sw-resize" ;;
          move)        echo "move fleur all-scroll size_all grabbing" ;;
          alternate)   echo "up-arrow center_ptr" ;;
          link)        echo "pointer hand hand1 hand2 pointing_hand" ;;
          *)           echo "" ;;
        esac
      }

      # role|file per line. CRLF because the file is Windows', and the
      # separator is | because every filename in it has spaces. Only the role
      # is case-folded -- folding the line renames every file it points at.
      tr -d '\r' < "$inf" \
        | sed -n '/\[Strings\]/,$p' \
        | sed -n 's/^[[:space:]]*\([A-Za-z_]*\)[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1|\2/p' \
        > roles.txt
      [ -s roles.txt ] || die "Installer.inf has no [Strings] role map"

      mkdir -p conv named
      while IFS='|' read -r role file; do
        role=$(printf '%s' "$role" | tr 'A-Z' 'a-z')
        # win2xcur names its output after the input, extension dropped.
        base=''${file%.*}
        names=$(x11names "$role")
        [ -n "$names" ] || continue

        # Two roles can share a file -- work and busy are both the loading
        # spinner in this pack -- so convert each file once.
        if [ ! -e "conv/$base" ]; then
          [ -f "./staged/cursors/$file" ] ||
            die "Installer.inf maps $role to cursors/$file, which the pack does not ship"
          win2xcur "./staged/cursors/$file" -o conv/ ||
            die "win2xcur could not convert cursors/$file"
        fi

        for n in $names; do
          cp "conv/$base" "named/$n"
        done
      done < roles.txt

      rm -rf ./staged/cursors
      mv named ./staged/cursors
    fi

    # Whatever the input was, a theme with no `default` is one every loader
    # falls back out of, silently.
    [ -s ./staged/cursors/default ] ||
      die "no cursors/default -- every loader falls out of this theme silently"

    # Without index.theme the theme is ignored just as quietly. A Windows pack
    # usually carries one already; write it when it does not.
    if [ ! -f ./staged/index.theme ]; then
      printf '[Icon Theme]\nName=%s\nComment=%s\nInherits=Adwaita\n' "$name" "$name" \
        > ./staged/index.theme
    fi

    mkdir -p "$out/share/icons"
    cp -r ./staged "$theme"

    # ── hyprcursors/ ────────────────────────────────────────────────────────
    # --extract writes beside its input, so it gets its own copy.
    cp -rL ./staged "./$name"
    hyprcursor-util --extract "./$name" >/dev/null

    # hyprcursor takes only [A-Za-z0-9_-.] in a shape directory name and in
    # the image names meta.hl points at, and an XCursor pack's masters can be
    # "05-Text Select" and friends. Substituting each whole filename, ".png"
    # included, since the format uses spaces as separators too.
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
    [ -f "$theme/manifest.hl" ] || die "hyprcursor produced no manifest.hl"
    [ -s "$theme/cursors/default" ] || die "the XCursor half lost its default"
    [ "$(ls "$theme/hyprcursors" | wc -l)" -gt 5 ] ||
      die "only $(ls "$theme/hyprcursors" | wc -l) hyprcursor shapes: the pack did not convert"
  ''
