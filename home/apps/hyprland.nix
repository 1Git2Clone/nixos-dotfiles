# The compositor's own config comes out of the dotfiles tree; what is here
# is the link to it and the reload a rebuild would otherwise not get.
{
  lib,
  osConfig,
  dotfiles,
  inputs,
  pkgs,
  ...
}:
let
  clipboardOcr = pkgs.writeShellApplication {
    name = "screenshot-ocr";
    runtimeInputs = [
      pkgs.wl-clipboard
      pkgs.tesseract
      pkgs.wofi
      pkgs.libnotify
    ];
    text = ''
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT
      if ! wl-paste --type image/png > "$work/capture.png"; then
        notify-send "Screenshot OCR" "Capture an image with HyprCapture first."
        exit 1
      fi
      language="''${1:-}"
      if [[ -z "$language" ]]; then
        language=$(tesseract --list-langs 2>/dev/null | tail -n +2 | \
          wofi --dmenu --prompt "OCR language") || exit 0
      fi
      [[ -n "$language" ]] || exit 0
      tesseract "$work/capture.png" stdout -l "$language" > "$work/text"
      if [[ ! -s "$work/text" ]]; then
        notify-send "Screenshot OCR" "No text found."
        exit 0
      fi
      wl-copy --type text/plain < "$work/text"
      notify-send "Screenshot OCR" "Text copied to clipboard."
    '';
  };
in
{
  _module.args.hyprcapture = import ../../pkgs/hyprcapture.nix { inherit inputs pkgs; };
  home.packages = [ clipboardOcr ];

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

      # The cursor is not config, so the reload above cannot carry it:
      # Hyprland loads a theme at launch from XCURSOR_THEME and otherwise only
      # on this command. Without it a switched pointer waits for the next
      # login, and until then the compositor draws the old theme while every
      # newly started client draws the new one -- the two halves of the same
      # rebuild, visibly disagreeing.
      run ${osConfig.programs.hyprland.package}/bin/hyprctl \
        -i "''${sig##*/}" setcursor \
        ${osConfig.stylix.cursor.name} ${toString osConfig.stylix.cursor.size} || true
    done
  '';
}
