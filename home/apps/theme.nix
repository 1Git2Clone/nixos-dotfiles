# Icons and the light/dark switch. The colours themselves are stylix's, set
# system-side in modules/desktop/stylix.nix.
{ pkgs, osConfig, ... }:
let
  folderIcons = pkgs.callPackage ../../pkgs/hutao-folder-icons.nix { };

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
}
