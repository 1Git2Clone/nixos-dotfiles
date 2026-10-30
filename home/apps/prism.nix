# Prism Launcher's "System" theme never takes the platform theme's colours (it
# keeps a palette captured at start-up), so it came up light on a dark desktop.
# A custom theme is the one way to hand it a palette; this is a caelestia
# template, so it follows a scheme switch the next time Prism starts. Pick it
# once under Settings > Appearance.
{ pkgs, palette, ... }:
let
  inherit (palette.template) hex;
in
{
  hutao.caelestiaTemplates."prism-theme.json" = {
    target = ".local/share/PrismLauncher/themes/caelestia/theme.json";
    source = (pkgs.formats.json { }).generate "prism-theme.json" {
      name = "Caelestia";
      widgets = "Darkly"; # the style qtengine names, so it matches the other Qt apps
      colors = {
        Window = hex.surface0;
        WindowText = hex.text;
        Base = hex.base;
        AlternateBase = hex.surface0;
        ToolTipBase = hex.surface2;
        ToolTipText = hex.text;
        Text = hex.text;
        Button = hex.surface1;
        ButtonText = hex.text;
        BrightText = hex.text;
        Link = hex.klink;
        Highlight = hex.primary;
        HighlightedText = hex.onPrimary;
      };
    };
  };
}
