# Desktop notifications for things that finish in a terminal you're not watching.
#
#   shell-notify visible
#       Exit 0 when the caller's terminal is on screen: its tmux pane is the
#       active one in an attached session and that client's window has
#       Hyprland's focus. notify.sh (Claude's hook) uses this too.
#   shell-notify send [--model M] <exit> <seconds> <start-line> <command>
#       Called by .zshrc for commands that ran long. Summarises the command
#       and its output into one line through OpenRouter, falling back to plain
#       text when there is no key, no network or no answer.

model="${SHELL_NOTIFY_MODEL:-deepseek/deepseek-v4.1-flash}"
head_lines=20 # first and last lines of output sent to the model
tail_lines=40
api_timeout=15 # seconds before giving up on the summary
sticky=3600000 # caelestia reads -t 0 as its 5s default; see notify.sh

# True when pid $1 is $2 or runs somewhere under it.
descends_from() {
  local pid=$1
  while ((pid > 1)); do
    ((pid == $2)) && return 0
    pid=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status" 2>/dev/null) || return 1
  done
  return 1
}

visible() {
  local focused client
  focused=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty')
  [[ -n $focused ]] || return 1

  if [[ -z ${TMUX_PANE:-} ]]; then
    descends_from "$PPID" "$focused"
    return
  fi

  [[ $(tmux display -p -t "$TMUX_PANE" \
    '#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}}') == 1 ]] || return 1
  # The terminal window is the ancestor of the tmux client, not of this pane.
  for client in $(tmux list-clients -t "$(tmux display -p -t "$TMUX_PANE" '#S')" -F '#{client_pid}'); do
    descends_from "$client" "$focused" && return 0
  done
  return 1
}

# The command's output: lines from <start-line> (absolute, history included,
# as preexec recorded it) to the cursor, trimmed to head + tail.
output() {
  local start=$1 now cursor total
  [[ -n ${TMUX_PANE:-} && $start =~ ^[0-9]+$ ]] || return 0
  read -r now cursor < <(tmux display -p -t "$TMUX_PANE" '#{history_size} #{cursor_y}')
  tmux capture-pane -p -J -t "$TMUX_PANE" -S $((start - now)) -E $((cursor - 1)) |
    cut -c1-300 >"$tmp"
  total=$(wc -l <"$tmp")
  if ((total > head_lines + tail_lines)); then
    head -n "$head_lines" "$tmp"
    echo "[... $((total - head_lines - tail_lines)) lines omitted ...]"
    tail -n "$tail_lines" "$tmp"
  else
    cat "$tmp"
  fi
}

summarise() {
  local status=$1 seconds=$2 cmd=$3 out=$4
  [[ -n ${OPENROUTER_API_KEY:-} ]] || return 1
  jq -n --arg model "$model" --arg cmd "$cmd" --arg status "$status" \
    --arg seconds "$seconds" --arg out "$out" '{
		model: $model,
		max_tokens: 60,
		reasoning: {enabled: false}, # else the tokens go to thinking and the answer is empty
		messages: [
			{role: "system", content: "You write the body of a desktop notification for a terminal command that just finished. One line, plain English, at most 90 characters, no quotes, no markdown. Say what the command did in everyday words (e.g. \"System update\" for nixos-rebuild) and whether it worked. On failure give the concrete reason from the output."},
			{role: "user", content: "Command: \($cmd)\nExit code: \($status)\nRan for: \($seconds)s\nOutput:\n\($out)"}
		]
	}' | curl -sS --max-time "$api_timeout" https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" -H 'Content-Type: application/json' -d @- |
    jq -er '.choices[0].message.content | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ") | select(length > 0)'
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
  local status=$1 seconds=$2 start=$3 cmd=$4 title=Shell body
  visible && return 0

  [[ -n ${TMUX_PANE:-} ]] && title="Shell $(tmux display -p -t "$TMUX_PANE" '#S:#P')"
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  if ! body=$(summarise "$status" "$seconds" "$cmd" "$(output "$start")"); then
    if ((status == 0)); then
      body="Finished running $cmd"
    else
      body="Failed: $cmd"
    fi
  fi
  notify-send -u normal -t "$sticky" -a Shell -i utilities-terminal-symbolic "$title" "[$status] | $body"
}

case "${1:-}" in
  visible) visible ;;
  send)
    shift
    send "$@"
    ;;
  *)
    echo "usage: shell-notify visible | send [--model M] <exit> <seconds> <start-line> <command>" >&2
    exit 2
    ;;
esac
