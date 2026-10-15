# Notifications for long terminal commands, summarised by an LLM; also the
# "is this pane on screen?" check Claude's notify.sh shares. hyprctl is left
# to PATH so it always matches the running Hyprland.
{
  writeShellApplication,
  coreutils,
  curl,
  gawk,
  jq,
  libnotify,
  tmux,
}:
writeShellApplication {
  name = "shell-notify";
  runtimeInputs = [
    coreutils
    curl
    gawk
    jq
    libnotify
    tmux
  ];
  text = builtins.readFile ./shell-notify/shell-notify.sh;
}
