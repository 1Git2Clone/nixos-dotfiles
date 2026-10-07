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
in
{
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
