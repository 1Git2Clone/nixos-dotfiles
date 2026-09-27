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
    polarity = palette.mode;

    # The 16 slots read straight out of the caelestia scheme by their
    # semantic names, so this and the shell cannot drift. See palette.nix.
    base16Scheme = palette.base16;

    # Wallpaper only; base16Scheme above is explicit, so nothing derives
    # colours from this. It is caelestia's current one, which the theme hook
    # records by name in current.json; the file itself has to be in the
    # private assets input. Limine takes it through stylix's limine target,
    # SDDM through sddm.nix.
    image =
      let
        name = (lib.importJSON ../../dotfiles/caelestia/current.json).wallpaper;
        image = inputs.third-party-assets + "/assets/third-party/Wallpapers/${name}";
      in
      if builtins.pathExists image then
        image
      else
        throw "caelestia's wallpaper ${name} is not in third-party-assets' Wallpapers; add it there and `nix flake update third-party-assets`.";

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

  # caelestia owns Qt: every scheme switch rewrites ~/.config/qtengine, which
  # is qtengine's config, and names Darkly as the style. stylix's qt target
  # would point QT_QPA_PLATFORMTHEME at qt5ct instead, whose colours only a
  # rebuild can change. qt.enable, with no platform theme of its own, is what
  # puts each profile's lib/qt-6/plugins on QT_PLUGIN_PATH, which is where
  # both plugins below are found. Qt 6 only: qtengine has no Qt 5 build.
  stylix.targets.qt.enable = false;
  qt.enable = true;
  environment.variables.QT_QPA_PLATFORMTHEME = "qtengine";
  environment.systemPackages = [
    pkgs.qtengine
    pkgs.darkly
  ];
}
