# Notifications for long terminal commands, summarised by an LLM; also the
# "is this pane on screen?" check Claude's notify.sh shares. hyprctl is left
# to PATH so it always matches the running Hyprland, and busctl too, so it
# talks to the running systemd.
{
  writeShellApplication,
  coreutils,
  curl,
  gawk,
  jq,
  libnotify,
  tmux,
  util-linux,
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
    util-linux
  ];
  text = builtins.readFile ./shell-notify/shell-notify.sh;
}
