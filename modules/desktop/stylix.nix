{
  lib,
  pkgs,
  palette,
  cursor,
  inputs,
  ...
}:
{
  stylix = {
    enable = true;
    polarity = "dark";

    # The 16 slots read straight out of the caelestia scheme by their
    # semantic names, so this and the shell cannot drift. See palette.nix.
    base16Scheme = palette.base16;

    # Wallpaper only; base16Scheme above is explicit, so nothing derives
    # colours from this.
    image = inputs.third-party-assets + "/assets/third-party/Wallpapers/Hu_Tao_00056_1.png";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      # kitty.conf's font_size.
      sizes = {
        terminal = 9;
        applications = 10;
        desktop = 10;
        popups = 10;
      };
    };

    opacity.terminal = 0.92;

    # The theme env.lua's XCURSOR_THEME names.
    cursor = {
      inherit (cursor) package name size;
    };
  };

  # stylix's qt target sets platformTheme = "qt5ct", which a Qt6 app cannot
  # load — QIcon::themeName() comes back empty and caelestia's launcher icons
  # all vanish. Keep the target, which is what installs the plugin and puts
  # lib/qt-6/plugins on QT_PLUGIN_PATH, and override only the name. Raw
  # variable and mkForce: the NixOS enum has no qt6ct value, and the target
  # defines this too.
  stylix.targets.qt.enable = true;
  environment.variables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
}
