# Desktop notifications for things that finish in a terminal you're not watching.
#
#   shell-notify visible [pane]
#       Exit 0 when the pane (default: the caller's) is on screen: it is the
#       active one in an attached session and that client's window has
#       Hyprland's focus. Exit 1 when it is not, and 2 when that cannot be
#       told, so callers notify rather than stay quiet. notify.sh (Claude's
#       hook) uses this too.
#   shell-notify notify <notify-send args>
#       notify-send that remembers the notification so it can be closed: under
#       the caller's tmux pane, or outside tmux under the processes above the
#       caller, one of which is the terminal window.
#   shell-notify dismiss <pane>
#       Close the pane's remembered notifications if it is on screen. tmux's
#       hooks call it on terminal focus and session, window and pane switches.
#   shell-notify watch
#       Follow Hyprland's focus and close the notifications sent outside tmux
#       from whichever window gains it. A user service runs it.
#   shell-notify send [--model M] <exit> <seconds> <start-line> <command>
#       Called by .zshrc for commands that ran long. Summarises the command
#       and its output into one line through OpenRouter, falling back to plain
#       text when there is no key, no network or no answer.
#
# Failures are logged, never swallowed: stderr goes nowhere from a tmux hook,
# so they also go to the journal (journalctl --user -t shell-notify).

model="${SHELL_NOTIFY_MODEL:-deepseek/deepseek-v4.1-flash}"
head_lines=20 # first and last lines of output sent to the model
tail_lines=40
api_timeout=15 # seconds before giving up on the summary
sticky=3600000 # caelestia reads -t 0 as its 5s default; see notify.sh
# One file of notification IDs per pane, named by its number (%27 -> 27), and
# outside tmux one file per notification, pid-<id>, listing the processes
# above its sender.
ids="${XDG_RUNTIME_DIR:-/tmp}/shell-notify"

log() {
  echo "shell-notify: $*" >&2
  # Under systemd stderr is already the journal; elsewhere it is not.
  [[ -n ${JOURNAL_STREAM:-} ]] || logger -t shell-notify -- "$*" ||
    echo "shell-notify: logger failed too; the line above is the only record" >&2
}

# Every process from pid $1 up to init, one per line.
ancestors() {
  local pid=$1
  while ((pid > 1)); do
    echo "$pid"
    # A process that exits mid-walk ends the chain; what was read stays true.
    pid=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status" 2>/dev/null) || return 0
  done
}

# True when pid $1 is $2 or runs somewhere under it. A process that has
# exited runs under nothing, so false is the right answer for it too.
descends_from() {
  # Not a pipe: grep -q stops reading at a match, and under pipefail the
  # SIGPIPE that leaves ancestors with would turn the match into a failure.
  grep -qx "$2" <<<"$(ancestors "$1")"
}

# The pid of the window with Hyprland's focus, or a logged failure.
focused_pid() {
  local out pid
  if ! out=$(hyprctl activewindow -j 2>&1); then
    log "hyprctl activewindow failed: $out"
    return 1
  fi
  pid=$(jq -r '.pid // empty' <<<"$out" 2>/dev/null) || pid=
  if [[ ! $pid =~ ^[0-9]+$ ]]; then
    # No window focused (an empty workspace) answers {} and is not an error.
    [[ $out == "{}" || $out == "Invalid" ]] && return 2
    log "hyprctl activewindow gave no pid: ${out:0:200}"
    return 1
  fi
  echo "$pid"
}

visible() {
  local pane=${1:-${TMUX_PANE:-}} focused state session clients client rc=0
  focused=$(focused_pid) || rc=$?
  case $rc in
    0) ;;
    2) return 1 ;; # nothing has focus, so nothing is on screen
    *) return 2 ;;
  esac

  if [[ -z $pane ]]; then
    descends_from "$PPID" "$focused" && return 0
    return 1
  fi

  if ! state=$(tmux display -p -t "$pane" \
    '#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}} #S' 2>&1); then
    log "tmux display for pane $pane failed: $state"
    return 2
  fi
  # tmux answers a pane that no longer exists with exit 0 and blank fields.
  if [[ ! $state =~ ^([01])\ (.+)$ ]]; then
    log "tmux has no pane $pane (got '$state')"
    return 2
  fi
  [[ ${BASH_REMATCH[1]} == 1 ]] || return 1
  session=${BASH_REMATCH[2]}
  # The terminal window is the ancestor of the tmux client, not of this pane.
  if ! clients=$(tmux list-clients -t "$session" -F '#{client_pid}' 2>&1); then
    log "tmux list-clients for session $session failed: $clients"
    return 2
  fi
  for client in $clients; do
    if [[ ! $client =~ ^[0-9]+$ ]]; then
      log "tmux list-clients for session $session gave a non-pid '$client'"
      return 2
    fi
    descends_from "$client" "$focused" && return 0
  done
  return 1
}

# The command's output: lines from <start-line> (absolute, history included,
# as preexec recorded it) to the cursor, trimmed to head + tail. Outside tmux,
# or without a start line, there is no output to read back, and the summary
# goes on from the command line alone.
output() {
  local start=$1 pos now cursor total
  [[ -n ${TMUX_PANE:-} && $start =~ ^[0-9]+$ ]] || return 0
  if ! pos=$(tmux display -p -t "$TMUX_PANE" '#{history_size} #{cursor_y}' 2>&1); then
    log "tmux display for $TMUX_PANE failed, summarising without output: $pos"
    return 0
  fi
  if [[ ! $pos =~ ^[0-9]+\ [0-9]+$ ]]; then
    log "tmux has no pane $TMUX_PANE (got '$pos'), summarising without output"
    return 0
  fi
  read -r now cursor <<<"$pos"
  if ! tmux capture-pane -p -J -t "$TMUX_PANE" -S $((start - now)) -E $((cursor - 1)) >"$tmp" 2>"$tmp.err"; then
    log "tmux capture-pane for $TMUX_PANE failed, summarising without output: $(<"$tmp.err")"
    return 0
  fi
  cut -c1-300 "$tmp" >"$tmp.cut"
  total=$(wc -l <"$tmp.cut")
  if ((total > head_lines + tail_lines)); then
    head -n "$head_lines" "$tmp.cut"
    echo "[... $((total - head_lines - tail_lines)) lines omitted ...]"
    tail -n "$tail_lines" "$tmp.cut"
  else
    cat "$tmp.cut"
  fi
}

summarise() {
  local status=$1 seconds=$2 cmd=$3 out=$4 resp answer
  if [[ -z ${OPENROUTER_API_KEY:-} ]]; then
    log "no OPENROUTER_API_KEY, using the plain-text body"
    return 1
  fi
  if ! resp=$(jq -n --arg model "$model" --arg cmd "$cmd" --arg status "$status" \
    --arg seconds "$seconds" --arg out "$out" '{
		model: $model,
		max_tokens: 60,
		reasoning: {enabled: false}, # else the tokens go to thinking and the answer is empty
		messages: [
			{role: "system", content: "You write the body of a desktop notification for a terminal command that just finished. One line, plain English, at most 90 characters, no quotes, no markdown. Say what the command did in everyday words (e.g. \"System update\" for nixos-rebuild) and whether it worked. On failure give the concrete reason from the output."},
			{role: "user", content: "Command: \($cmd)\nExit code: \($status)\nRan for: \($seconds)s\nOutput:\n\($out)"}
		]
	}' | curl -sS --max-time "$api_timeout" https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" -H 'Content-Type: application/json' -d @- 2>&1); then
    log "summary request failed, using the plain-text body: $resp"
    return 1
  fi
  if ! answer=$(jq -er '.choices[0].message.content | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ") | select(length > 0)' <<<"$resp" 2>/dev/null); then
    log "summary response had no answer, using the plain-text body: ${resp:0:300}"
    return 1
  fi
  echo "$answer"
}

send() {
  if [[ ${1:-} == --model ]]; then
    model=$2
    shift 2
  fi
  (($# == 4)) || {
    echo "usage: shell-notify send [--model M] <exit> <seconds> <start-line> <command>" >&2
    exit 2
  }
  local status=$1 seconds=$2 start=$3 cmd=$4 title=Shell body name rc=0
  visible || rc=$?
  # 0: on screen, nothing to say. 1: not on screen. 2: unknown, already
  # logged, and a notification too many beats one missed.
  ((rc == 0)) && return 0

  if [[ -n ${TMUX_PANE:-} ]]; then
    if name=$(tmux display -p -t "$TMUX_PANE" '#S:#P' 2>&1) && [[ $name =~ ^.+:[0-9]+$ ]]; then
      title="Shell $name"
    else
      log "tmux gave no name for $TMUX_PANE ('$name'), titling it plain Shell"
    fi
  fi
  tmp=$(mktemp)
  trap 'rm -f "$tmp" "$tmp.err" "$tmp.cut"' EXIT
  if ! body=$(summarise "$status" "$seconds" "$cmd" "$(output "$start")"); then
    if ((status == 0)); then
      body="Finished running $cmd"
    else
      body="Failed: $cmd"
    fi
  fi
  notify -u normal -t "$sticky" -a Shell -i utilities-terminal-symbolic "$title" "[$status] | $body"
}

notify() {
  local id chain
  if ! id=$(notify-send -p "$@"); then
    log "notify-send failed: $*"
    return 1
  fi
  if [[ ! $id =~ ^[0-9]+$ ]]; then
    log "notify-send printed no notification ID ('$id'), so it cannot be dismissed on focus"
    return 1
  fi
  if ! mkdir -p "$ids"; then
    log "notification $id: cannot create $ids, so it cannot be dismissed on focus"
    return 1
  fi
  if [[ -n ${TMUX_PANE:-} ]]; then
    if ! echo "$id" >>"$ids/${TMUX_PANE#%}"; then
      log "notification $id: cannot record it for pane $TMUX_PANE"
      return 1
    fi
    return 0
  fi
  # No pane to file it under: keep the processes above the sender, and close
  # it once one of them is the focused window.
  chain=$(ancestors "$PPID")
  if [[ -z $chain ]]; then
    log "notification $id: sender $PPID already exited, so it cannot be dismissed on focus"
    return 1
  fi
  if ! echo "$chain" >"$ids/pid-$id"; then
    log "notification $id: cannot record it in $ids"
    return 1
  fi
}

# Close one notification. An ID caelestia no longer has closes without error,
# so a failure here is the notification daemon itself, and the ID is kept.
close() {
  local out
  if ! out=$(busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications \
    org.freedesktop.Notifications CloseNotification u "$1" 2>&1); then
    log "closing notification $1 failed, keeping it to retry: $out"
    return 1
  fi
}

dismiss() {
  local pane=$1 file id rc=0 keep=()
  file="$ids/${pane#%}"
  # Nothing was sent from this pane.
  [[ -f $file ]] || return 0
  visible "$pane" || rc=$?
  case $rc in
    0) ;;
    1) return 0 ;; # not on screen yet; the next focus tries again
    *) return 1 ;; # logged by visible; the IDs stay for the next focus
  esac
  # Pane and notification numbers restart with tmux and caelestia, so a file
  # kept across either could name someone else's notification; both live in
  # XDG_RUNTIME_DIR, which logout clears.
  while read -r id; do
    close "$id" || keep+=("$id")
  done <"$file"
  if ((${#keep[@]})); then
    printf '%s\n' "${keep[@]}" >"$file"
    return 1
  fi
  rm -f "$file"
}

# Close the notifications sent outside tmux from the focused window.
dismiss_focused() {
  local focused f rc=0 failed=0
  focused=$(focused_pid) || rc=$?
  case $rc in
    0) ;;
    2) return 0 ;; # nothing has focus
    *) return 1 ;; # logged by focused_pid
  esac
  for f in "$ids"/pid-*; do
    [[ -e $f ]] || continue # the glob matched nothing
    grep -qx "$focused" "$f" || continue
    if close "${f##*/pid-}"; then
      rm -f "$f"
    else
      failed=1
    fi
  done
  return "$failed"
}

watch() {
  local sock="${XDG_RUNTIME_DIR:-}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock" line
  if [[ -z ${XDG_RUNTIME_DIR:-} || -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    log "watch: XDG_RUNTIME_DIR or HYPRLAND_INSTANCE_SIGNATURE is unset"
    exit 1
  fi
  if [[ ! -S $sock ]]; then
    log "watch: no Hyprland event socket at $sock"
    exit 1
  fi
  if socat -U - "UNIX-CONNECT:$sock" | while read -r line; do
    if [[ $line == 'activewindowv2>>'* ]]; then
      # Failures are logged inside, and one bad focus must not end the watch.
      dismiss_focused || :
    fi
  done; then
    log "watch: Hyprland closed its event socket"
  else
    log "watch: reading Hyprland's event socket failed (exit $?)"
  fi
  # Either way the watch is over; exit non-zero so systemd restarts it.
  exit 1
}

case "${1:-}" in
  visible) visible "${2:-}" ;;
  notify)
    shift
    notify "$@"
    ;;
  dismiss) dismiss "${2:?usage: shell-notify dismiss <pane>}" ;;
  watch) watch ;;
  send)
    shift
    send "$@"
    ;;
  *)
    echo "usage: shell-notify visible [pane] | notify <args> | dismiss <pane> | watch | send [--model M] <exit> <seconds> <start-line> <command>" >&2
    exit 2
    ;;
esac
