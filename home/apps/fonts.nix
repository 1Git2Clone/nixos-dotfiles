# One font for every UI. hutao.uiFont is the switch; this file and the few
# that cannot live here read it: caelestia.nix (qtengine), dotfiles.nix
# (Discord, fcitx5).
#
# fontconfig's defaults stay stylix's sansSerif and serif, so web pages and
# LibreOffice documents are untouched -- a document asking for Calibri falls
# back to sans-serif, and that should not be a monospace.
{
  lib,
  config,
  osConfig,
  ...
}:
let
  ui = config.hutao.uiFont;
  inherit (osConfig.stylix.fonts) monospace;
in
{
  options.hutao.uiFont = lib.mkOption {
    type = lib.types.attrs;
    default = monospace;
    description = ''
      The font of every UI: GTK (and so the browsers', Nautilus', Evolution's
      and LibreOffice's chrome), Qt, the caelestia shell, Discord and fcitx5.
      A stylix font, `{ package, name }`.
    '';
  };

  config = {
    gtk.font = {
      inherit (ui) package name;
      size = osConfig.stylix.fonts.sizes.applications;
    };

    # Merged over the vendored shell.json by the module.
    programs.caelestia.settings.appearance.font = {
      headline.family = ui.name;
      # The lock screen draws the clock, weather and resources from
      # headline.large (the clock at 7x) and narrows them with the wdth axis,
      # which GoogleSansFlex has and a monospace does not; 32 overflows.
      headline.large.size = 24;
      title.family = ui.name;
      body.family = ui.name;
      label.family = ui.name;
      mono.family = monospace.name;
      clock = ui.name;
      workspaces = ui.name;
    };
  };
}
