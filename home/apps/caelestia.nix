# The shell: its module, the scheme it switches with, and the state it
# expects to already exist.
{
  pkgs,
  lib,
  config,
  palette,
  dotfiles,
  ...
}:
let
  caelestiaScheme = (pkgs.formats.json { }).generate "caelestia-scheme.json" palette.schemeJson;

in
{
  programs.caelestia = {
    enable = true;
    cli.enable = true;
    # autostart.lua already execs it; true here double-starts.
    systemd.enable = false;
    # shell.json is gitignored upstream, so it is vendored here.
    extraConfig = builtins.readFile ../caelestia-shell.json;
  };

  xdg.configFile = {
    # Outside the dot-* trees, so the walk never reaches it.
    "caelestia/schemes/hu-tao/default/dark.txt".source =
      ../../dotfiles/caelestia/schemes/hu-tao/default/dark.txt;

    # caelestia creates these itself, but after Hyprland reads its config.
    "caelestia/hypr-user.conf".text = "";
    "caelestia/hypr-vars.conf".text = "";
  };

  # caelestia's face picker writes to ~/.face, so seed it.
  home.activation.face = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${config.home.homeDirectory}/.face" ]; then
      run cp -L ${dotfiles}/dot-config/fastfetch/icons/HuTaoSmall.png \
        "${config.home.homeDirectory}/.face"
      run chmod u+w "${config.home.homeDirectory}/.face"
    fi
  '';

  # Personal data that is not in the repo, so a fresh machine starts empty.
  home.activation.wallpapers =
    let
      dir = "${config.home.homeDirectory}/Pictures/Wallpapers";
      state = "${config.xdg.stateHome}/caelestia/wallpaper";
      # `caelestia wallpaper` rewrites both.
      current = "${dir}/Hu_Tao_00056_1.png";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${dir}" ]; then
        run mkdir -p "${dir}"
        run cp -L ${dotfiles}/dot-config/hypr/backgrounds/* "${dir}"/
        run chmod u+w "${dir}"/*
      fi

      if [ ! -e "${state}/path.txt" ]; then
        run mkdir -p "${state}"
        run ln -sfn "${current}" "${state}/current"
        printf '%s\n' "${current}" > "${state}/path.txt"
      fi
    '';

  # The shell is a Qt process that caches every icon lookup it makes, and it
  # resolves them out of whichever profile held app-icons when it started.
  # Moving that package between environment.systemPackages and home.packages
  # therefore breaks the launcher's icons in a live session and nothing short
  # of a restart fixes it -- the files are correct, the process is not. There
  # is no reload in the shell's IPC (`caelestia shell -s`), so it has to be
  # killed and started again.
  #
  # The switch itself runs with no session attached, so `-d` on its own would
  # find no Wayland display: the env comes off the process being replaced, and
  # the kill only happens once that has been read. Best-effort throughout,
  # like the hyprland reload below -- no shell running, nothing to do, and a
  # failure here must not fail the switch.
  home.activation.caelestiaReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    pid=$(${pkgs.procps}/bin/pgrep -u "$UID" -x quickshell 2>/dev/null | head -1 || true)
    if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
      wl=$(tr '\0' '\n' < "/proc/$pid/environ" | grep -m1 '^WAYLAND_DISPLAY=' || true)
      sig=$(tr '\0' '\n' < "/proc/$pid/environ" | grep -m1 '^HYPRLAND_INSTANCE_SIGNATURE=' || true)
      if [ -n "$wl" ]; then
        run ${config.programs.caelestia.package}/bin/caelestia shell -k || true
        run env "$wl" "$sig" \
          ${config.programs.caelestia.package}/bin/caelestia shell -d || true
      fi
    fi
  '';

  home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state="${config.xdg.stateHome}/caelestia"
    if [ ! -e "$state/scheme.json" ]; then
      run mkdir -p "$state"
      run install -m600 ${caelestiaScheme} "$state/scheme.json"
    fi
  '';
}
