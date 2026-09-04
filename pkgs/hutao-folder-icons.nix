# A Windows folder-icon pack as a freedesktop icon theme — see
# assets/Hutao-Folders/ORIGIN.md.
#
# Each .ico carries the same drawing thirteen times: legacy 4- and 8-bit
# entries, seven 32-bit ones from 16 to 64, and a PNG-compressed 256. icotool
# pulls out the 32-bit set, so nothing is upscaled and no size is redrawn by a
# resampler.
#
# Inherits Papirus-Dark, which is what qt6ct was already set to: the pack
# covers folders, trash, computer, network and disks, and everything else in a
# file manager still has to come from somewhere. Point `Inherits` at Adwaita
# instead to keep GTK's default set underneath.
{
  lib,
  runCommandLocal,
  icoutils,
}:
let
  theme = "Hutao-Folders";

  # Sizes to lift out, all present in every file as 32-bit entries.
  sizes = [
    16
    24
    32
    48
    64
    256
  ];

  # The freedesktop names each drawing answers to. A name absent here falls
  # through to Papirus, which is why the plain folder claims the four XDG
  # directories the pack has no art for -- a lone blue Downloads among these
  # reads worse than a Hu Tao folder without a download arrow.
  #
  # Add a name to point more of the desktop at art that is already here.
  icons = {
    "01-Default Folder (Red)" = [
      "folder"
      "folder-open"
      "folder-visiting"
      "folder-drag-accept"
      "folder-desktop"
      "user-desktop"
      "folder-templates"
      "folder-publicshare"
      "folder-download"
      "folder-downloads"
      "folder-home"
      "user-home"
    ];

    # No standard name, so these two are only reachable by asking for them --
    # a file manager that sets a per-folder icon, or swapping which of the
    # three defaults owns `folder` above.
    "01-Default Folder (Dark Brown)" = [ "folder-hutao-brown" ];
    "01-Default Folder (Soft Gold)" = [ "folder-hutao-gold" ];

    "02-Picture Folder" = [
      "folder-pictures"
      "folder-images"
      "folder-image"
    ];
    "03-Music Folder" = [
      "folder-music"
      "folder-sound"
    ];
    "04-Video Folder" = [
      "folder-videos"
      "folder-video"
    ];
    "05-Favorite Folder" = [
      "folder-favorites"
      "folder-bookmark"
      "folder-bookmarks"
      "folder-star"
      "folder-starred"
    ];
    "06-Document Folder" = [
      "folder-documents"
      "folder-text"
    ];
    "07-Message Folder" = [
      "folder-mail"
      "folder-chat"
    ];
    "08-Secret Folder" = [
      "folder-locked"
      "folder-lock"
      "folder-private"
      "folder-secure"
    ];
    "09-This PC" = [
      "computer"
      "gnome-dev-computer"
    ];
    "10-Network" = [
      "folder-network"
      "folder-remote"
      "network-workgroup"
      "network-server"
    ];

    # Not drive-removable-media: the drawing is a rack of bays, and a USB
    # stick should still look like a USB stick.
    "11-Disk" = [
      "drive-harddisk"
      "drive-harddisk-system"
      "drive-multidisk"
    ];

    "12.1-Empty Bin" = [
      "user-trash"
      "user-trash-empty"
      "trash-empty"
    ];
    "12.2-Full Bin" = [
      "user-trash-full"
      "trash-full"
    ];
  };

  # One places/ per size and nothing else: GtkIconTheme looks a name up across
  # every directory the index lists and ignores Context, so splitting devices/
  # out would only make the index longer.
  dir = size: "${toString size}x${toString size}/places";

  # Thresholds rather than Fixed, and the 256 declared Scalable up to 512 the
  # way Papirus declares its own largest directory. Between them the sizes
  # nothing here ships -- 22 in a GTK3 sidebar, 96 and 128 in nautilus' larger
  # zooms -- resolve to the nearest drawing rather than falling through to
  # Papirus, which would read as a folder that changes colour when the view is
  # zoomed.
  entry =
    size:
    [
      "[${dir size}]"
      "Size=${toString size}"
      "Context=Places"
    ]
    ++ (
      if size == 256 then
        [
          "Type=Scalable"
          "MinSize=80"
          "MaxSize=512"
        ]
      else
        [
          "Type=Threshold"
          "Threshold=${toString (size / 4 + 1)}"
        ]
    )
    ++ [ "" ];

  index = lib.concatStringsSep "\n" (
    [
      "[Icon Theme]"
      "Name=${theme}"
      "Comment=Pixel-art Hu Tao folders, over Papirus-Dark"
      "Inherits=Papirus-Dark,Adwaita,hicolor"
      "Directories=${lib.concatMapStringsSep "," dir sizes}"
      ""
    ]
    ++ lib.concatMap entry sizes
  );

  names = lib.flatten (lib.attrValues icons);
in
runCommandLocal "hutao-folder-icons"
  {
    nativeBuildInputs = [ icoutils ];

    # Artwork of unknown authorship, kept for one desktop rather than
    # redistributed. No license attr, so allowUnfree is not needed -- same
    # footing as hutao-cursor.
    meta = {
      description = "Hu Tao pixel-art folder icons, ported from a Windows .ico pack";
      platforms = lib.platforms.linux;
    };
  }
  ''
    theme="$out/share/icons/${theme}"

    ${lib.concatMapStringsSep "\n" (size: ''mkdir -p "$theme/${dir size}"'') sizes}

    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (src: iconNames: ''
        # Everything, rather than the six sizes wanted: asked for one entry by
        # --width/--height, icotool validates them all first and every file
        # here carries a legacy 4-bit entry that declares the wrong bitmap
        # size, so the whole .ico is refused. Extracting skips that path. The
        # frames come back named <base>_<index>_<w>x<h>x<depth>.png, which is
        # what the globs below pick 32-bit entries out of.
        rm -rf frames && mkdir frames
        icotool -x -o frames "${../assets/Hutao-Folders}/${src}.ico"
        ${lib.concatMapStringsSep "\n" (
          size:
          lib.concatMapStringsSep "\n" (
            n: ''cp frames/*_${toString size}x${toString size}x32.png "$theme/${dir size}/${n}.png"''
          ) iconNames
        ) sizes}
      '') icons
    )}
    rm -rf frames

    printf '%s' ${lib.escapeShellArg index} > "$theme/index.theme"

    # Without index.theme the theme is invisible to every loader, and a name
    # missing at one size falls through to Papirus for that size alone --
    # which shows up as a folder that changes colour when the view is zoomed.
    test -f "$theme/index.theme"
    ${lib.concatMapStringsSep "\n" (size: ''
      test "$(ls "$theme/${dir size}" | wc -l)" -eq ${toString (builtins.length names)}
    '') sizes}
  ''
