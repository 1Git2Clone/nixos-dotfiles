# workmux's dashboard and sidebar colours, as ANSI names so they follow
# kitty's palette, which caelestia recolours live. The text is the one colour
# off the ANSI 16: nvim's comment pink, read from the scheme at rebuild.
{
  config,
  lib,
  pkgs,
  palette,
  ...
}:
let
  settings = (pkgs.formats.yaml { }).generate "workmux.yaml" {
    nerdfont = true;
    # Inside the repo, not a <repo>__worktrees sibling: ghq owns the level
    # beside it and would list each sibling worktree as a repo of its own.
    worktree_dir = ".worktrees";
    # info/exclude rather than a global ignore: it is per clone, so a fresh
    # `ghq get` gets it on its first worktree.
    post_create = [
      ''e="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF .worktrees "$e" 2>/dev/null || echo .worktrees >> "$e"''
    ];
    theme = {
      mode = "dark";
      custom = {
        text = palette.hex.primaryFixedDim;
        dimmed = "8";
        border = "red";
        help_border = "red";
        help_muted = "8";
        header = "lightred";
        accent = "lightred";
        current_worktree_fg = "lightred";
        keycap = "yellow";
        info = "magenta";
        success = "green";
        warning = "yellow";
        danger = "red";
        current_row_bg = "black";
        highlight_row_bg = "0";
      };
    };
  };

  # The sidebar is 45 columns, too much of a narrow window. dot-tmux.conf runs
  # this on resizes: it hides the sidebar in the session when the window is
  # under 190 columns (~73% of a full-screen kitty, 261) and brings it back
  # once it is wider. `workmux sidebar --session` toggles the session in
  # @workmux_sidebar_optout_sessions, so it only runs when that disagrees.
  # ponytail: also undoes a by-hand `--session` hide on the next wide resize.
  sidebar-fit = pkgs.writeShellScriptBin "tmux-sidebar-fit" ''
    session=$1 width=$2 pane=$3
    if tmux show -gqv @workmux_sidebar_optout_sessions | grep -o '\$[0-9]*' | grep -qxF "$session"; then
      hidden=1
    else
      hidden=0
    fi
    if [ "$width" -lt 190 ]; then want=1; else want=0; fi
    [ "$hidden" = "$want" ] || TMUX_PANE=$pane workmux sidebar --session
  '';
in
{
  home.packages = [ sidebar-fit ];

  # workmux writes config.yaml itself (`T` in the dashboard saves the scheme
  # there), so ours is merged over it on every rebuild rather than linked.
  home.activation.workmuxSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf="${config.xdg.configHome}/workmux/config.yaml"
    run mkdir -p "$(dirname "$conf")"
    if [ -s "$conf" ]; then
      run ${lib.getExe pkgs.yq-go} eval-all '. as $i ireduce ({}; . * $i)' "$conf" ${settings} > "$conf.tmp"
      run mv "$conf.tmp" "$conf"
    else
      run install -m644 ${settings} "$conf"
    fi
  '';
}
