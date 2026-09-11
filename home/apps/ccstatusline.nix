# The Claude Code status line's settings.
{
  # Immutable on purpose, so the picker cannot save over it. `version`
  # must match the CURRENT_VERSION of whatever npm serves: on a lower one
  # the tool migrates, writes the result back into /nix/store, hits EROFS
  # and renders "invalid config" off its defaults.
  xdg.configFile."ccstatusline/settings.json".source = ../ccstatusline.json;
}
