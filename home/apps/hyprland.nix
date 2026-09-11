# The compositor's own config comes out of the dotfiles tree; what is here
# is the link to it and the reload a rebuild would otherwise not get.
{
  lib,
  osConfig,
  dotfiles,
  ...
}:
{
  # Patched and given its monitors.lua by `df`.
  xdg.configFile."hypr".source = "${dotfiles}/dot-config/hypr";

  # Hyprland reads its config once, at launch, and watches that file for
  # changes. A rebuild never changes a file: it points ~/.config/hypr at a new
  # store path, and the old immutable one the watcher holds is never touched.
  # So autoreload cannot fire, and an edit sits in the store doing nothing
  # until the next login -- which presents as "I changed the config, rebuilt,
  # and nothing happened".
  #
  # After linkGeneration, not writeBoundary: writeBoundary entries run before
  # the new symlinks are in place, so a reload there would re-read the old
  # config. `hyprctl -i` takes a signature, and finds its own runtime dir when
  # XDG_RUNTIME_DIR is unset, which it is in the activation service.
  #
  # Unconditional, rather than diffing generations first: reloading a config
  # that did not change costs nothing, and the dotfiles are one derivation, so
  # a diff could not tell a hypr edit from a waybar one anyway.
  home.activation.hyprlandReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for sock in "''${XDG_RUNTIME_DIR:-/run/user/$UID}"/hypr/*/.socket.sock; do
      # No instance running (a first login, or a rebuild over ssh).
      [ -S "$sock" ] || continue

      sig=''${sock%/.socket.sock}
      # A reload is best-effort: a stale socket must not fail the switch.
      run ${osConfig.programs.hyprland.package}/bin/hyprctl \
        -i "''${sig##*/}" reload || true
    done
  '';

}
