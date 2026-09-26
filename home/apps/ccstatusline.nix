# The Claude Code status line's settings.
{
  lib,
  pkgs,
  palette,
  ...
}:
{
  # A caelestia template, for the gradient: ccstatusline re-reads its settings
  # on every render, so the text follows a scheme switch at once. The rendered
  # file is writable, so the picker can save over it, but only until the next
  # switch renders it again. `version` must still match the CURRENT_VERSION of
  # whatever npm serves, or every render migrates it.
  hutao.caelestiaTemplates."ccstatusline-settings.json" = {
    target = ".config/ccstatusline/settings.json";
    source = (pkgs.formats.json { }).generate "ccstatusline-settings.json" (
      lib.importJSON ../ccstatusline.json
      // {
        overrideForegroundColor = "gradient:${palette.template.hex.primary},${palette.template.hex.tertiary}";
      }
    );
  };
}
