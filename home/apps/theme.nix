# GTK, Qt and KDE's colours, all of which caelestia rewrites on every scheme
# switch: GTK and Qt through its own appliers (enableGtk, enableQt), KDE
# through a template here. What is left for a rebuild is the theme each one
# starts from, the fonts and the icons.
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
  # gtk included: caelestia writes gtk-3.0/gtk.css and gtk-4.0/gtk.css.
  stylix.autoEnable = false;

  # What stylix's gtk target set besides colours. adw-gtk3-dark because that
  # is the name caelestia writes to dconf, and its gtk.css is written against
  # it. No gtk4 theme: home-manager would write gtk-4.0/gtk.css to import it,
  # and that file is caelestia's.
  gtk = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    gtk4.theme = null;
    font = {
      inherit (osConfig.stylix.fonts.sansSerif) package name;
      size = osConfig.stylix.fonts.sizes.applications;
    };
  };

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

  # libadwaita decides light or dark from this key and nothing else. The
  # gtk.css repaints every named colour dark, but a GTK4 app still comes up on
  # libadwaita's light palette until the key says otherwise -- which is why
  # nautilus was white with hu-tao accents. caelestia sets it on every switch
  # too; this is the value until it first has, read off the scheme's mode.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if palette.mode == "light" then "prefer-light" else "prefer-dark";

  # The GTK3 half of the same switch, for apps that read the setting rather
  # than the theme's colours (Firefox picks its own light/dark off it).
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = palette.mode != "light";
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = palette.mode != "light";

  # Kirigami/QtQuick apps (ktailctl today, any KDE app later) read
  # KColorScheme, which reads kdeglobals and nothing else -- not qtengine's
  # colours. With no kdeglobals they come up on stock Breeze light, a white
  # window on a dark desktop. A caelestia template, so it follows a switch
  # the next time such an app starts.
  #
  # The scheme already names KDE's own roles -- klink, kvisited, knegative,
  # kneutral, kpositive and a *Selection variant of each -- so the foreground
  # mapping below is caelestia's semantics rather than a guess.
  hutao.caelestiaTemplates."kdeglobals" = {
    target = ".config/kdeglobals";
    source = pkgs.writeText "kdeglobals" (
      let
        inherit (palette.template) rgb;

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
      ]
    );
  };
}
