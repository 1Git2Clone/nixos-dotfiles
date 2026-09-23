# Icons and the light/dark switch. The colours themselves are stylix's, set
# system-side in modules/desktop/stylix.nix.
{
  lib,
  pkgs,
  inputs,
  osConfig,
  palette,
  ...
}:
let
  folderIcons = pkgs.callPackage ../../pkgs/hutao-folder-icons.nix {
    thirdParty = inputs.third-party-assets;
  };

  # Icons for the hand-written ~/.local/share/applications entries.
in
{
  # We own ~/.config wholesale; stylix's targets would be a second writer.
  stylix.autoEnable = false;
  stylix.targets.gtk.enable = true;

  # Nothing set an icon theme before this, which left every GTK app on
  # Adwaita's default while qt6ct was pointed at Papirus-Dark. Hutao-Folders
  # inherits Papirus-Dark, so this is also what settles that split -- the
  # folders come from the pack, everything else from the set Qt was already
  # using. home-manager writes it to both gtk-3.0 and gtk-4.0 settings.ini and
  # mirrors it into dconf, which is the one nautilus reads.
  gtk.iconTheme = {
    package = folderIcons;
    name = folderIcons.themeName;
  };

  # libadwaita decides light or dark from this key and nothing else. stylix's
  # gtk.css repaints every named colour dark, but a GTK4 app still comes up on
  # libadwaita's light palette until the key says otherwise -- which is why
  # nautilus was white with hu-tao accents. The only stylix target that sets
  # it is `gnome`, gated on GDM or the GNOME desktop being enabled, so on
  # Hyprland it never runs. Read off polarity rather than hardcoded, so
  # flipping stylix flips this too.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if osConfig.stylix.polarity == "light" then "prefer-light" else "prefer-dark";

  # The GTK3 half of the same switch, for apps that read the setting rather
  # than the theme's colours (Firefox picks its own light/dark off it).
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = osConfig.stylix.polarity != "light";
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = osConfig.stylix.polarity != "light";

  # What qt6ct reads for the icon theme; hyprqt6engine.conf is the Arch
  # half of the same setting. Hutao-Folders inherits Papirus-Dark, so a Qt
  # app sees what it saw before plus the folders.
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    icon_theme=${folderIcons.themeName}
  '';

  # Kirigami/QtQuick apps (ktailctl today, any KDE app later) take no colour
  # from stylix at all: its qt target writes qt6ct, which is the QtWidgets
  # half, while KColorScheme reads kdeglobals and nothing else. With no
  # kdeglobals they come up on stock Breeze light -- a white window on a dark
  # desktop. stylix will not grow this on its own; modules/qt/hm.nix warns
  # that any platform but qtct is unsupported, and `kdeglobals` appears
  # nowhere in its module tree.
  #
  # The scheme already names KDE's own roles -- klink, kvisited, knegative,
  # kneutral, kpositive and a *Selection variant of each -- so the foreground
  # mapping below is caelestia's semantics rather than a guess.
  xdg.configFile."kdeglobals".text =
    let
      inherit (palette) rgb;

      # All seven groups take the same twelve keys and differ only in their
      # surfaces, so the roles are written once.
      group =
        name:
        {
          bg,
          alt,
          fg ? "text",
          inactive ? "subtext0",
          active ? "primary",
          # [Colors:Selection] sits on the accent, so it gets the scheme's
          # *Selection variants: the same roles, legible against that instead
          # of against a surface.
          sel ? "",
        }:
        ''
          [Colors:${name}]
          BackgroundNormal=${rgb bg}
          BackgroundAlternate=${rgb alt}
          ForegroundNormal=${rgb fg}
          ForegroundInactive=${rgb inactive}
          ForegroundActive=${rgb active}
          ForegroundLink=${rgb "klink${sel}"}
          ForegroundVisited=${rgb "kvisited${sel}"}
          ForegroundNegative=${rgb "knegative${sel}"}
          ForegroundNeutral=${rgb "kneutral${sel}"}
          ForegroundPositive=${rgb "kpositive${sel}"}
          DecorationFocus=${rgb "primary"}
          DecorationHover=${rgb "primary"}
        '';
    in
    lib.concatStrings [
      ''
        [General]
        ColorScheme=${palette.schemeJson.name}
      ''
      # Breeze puts the view below the window, not above it: the insets a
      # window frames -- lists, text fields, the detail pane -- are the darkest
      # thing on screen and the chrome is raised off them. So the surface
      # ladder is read bottom-up, one rung per group, and every group's
      # alternate is the next rung so alternating list rows actually differ.
      # `mantle` is skipped on purpose: this scheme sets it equal to `base`.
      (group "View" {
        bg = "base";
        alt = "surface0";
      })
      (group "Window" {
        bg = "surface0";
        alt = "surface1";
      })
      (group "Button" {
        bg = "surface1";
        alt = "surface2";
      })
      (group "Tooltip" {
        bg = "surface2";
        alt = "surface1";
      })
      # Kirigami's toolbars and its sidebar respectively; the sidebar drops
      # below the view rather than rising above it, which is what separates
      # ktailctl's node list from the pane beside it.
      (group "Header" {
        bg = "surface1";
        alt = "surface2";
      })
      (group "Complementary" {
        bg = "crust";
        alt = "base";
      })
      (group "Selection" {
        bg = "primary";
        alt = "primary";
        fg = "onPrimary";
        inactive = "onPrimary";
        active = "onPrimary";
        sel = "Selection";
      })
    ];
}
