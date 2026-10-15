#!/usr/bin/env bash
# Sticky desktop notification when Claude needs the user: a long turn finished
# (Stop) or a question/permission prompt is waiting (Notification, AskUserQuestion).
# Usage: notify.sh start|done|ask   (hook JSON on stdin)
set -uo pipefail

LONG=60 # seconds a turn must run before "done" is worth interrupting for
# caelestia-shell reads -t 0 as "use the 5s default" and ignores urgency, so
# "sticky" is a timeout long enough to outlast the user (ms).
STICKY=3600000
input="$(cat)"
sid="$(jq -r '.session_id // "x"' <<<"$input")"
stamp="${XDG_RUNTIME_DIR:-/tmp}/claude-turn-$sid"

# caelestia can only tint an icon its own on-container colour, so paint the
# logo in the scheme's secondary per send; it follows scheme changes. Without a
# scheme, fall back to caelestia's tint.
icon=claude-symbolic
hex="$(jq -r '.colours.secondary // empty' "${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json" 2>/dev/null)"
if [[ $hex =~ ^[0-9a-fA-F]{6}$ ]]; then
  # Named by colour: caelestia caches icons by path.
  icon="${XDG_RUNTIME_DIR:-/tmp}/claude-icon-$hex.svg"
  [[ -f $icon ]] || sed "s/fill=\"#444444\"/fill=\"#$hex\"/" \
    "/etc/profiles/per-user/$USER/share/icons/hicolor/scalable/apps/claude-symbolic.svg" >"$icon"
fi

case "$1" in
  start) date +%s >"$stamp" ;;
  # Nothing to say when this pane is already on screen.
  done | ask) shell-notify visible && exit 0 ;;&
  done)
    [[ -f $stamp ]] || exit 0
    (($(date +%s) - $(<"$stamp") >= LONG)) || exit 0
    shell-notify notify -u normal -t "$STICKY" -a "Claude Code" -i "$icon" "Done" "${PWD##*/}"
    ;;
  ask)
    msg="$(jq -r '.message // "Waiting for your answer"' <<<"$input")"
    shell-notify notify -u normal -t "$STICKY" -a "Claude Code" -i "$icon" "Needs you: ${PWD##*/}" "$msg"
    ;;
esac
exit 0
