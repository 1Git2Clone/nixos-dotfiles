# bb, an agentic IDE over the coding agents already installed (Claude Code
# and opencode), run as its server alone: the web UI on localhost:38886 opens
# in the browser, and `bb` drives threads from a terminal. The desktop
# AppImage held ~2.4G in its own Electron; the server is ~660M (measured
# 2026-10-29).
#
# bb ships through npm with native modules (better-sqlite3, node-pty) that
# npm builds or fetches on install, so this runs a pinned version through npx
# rather than packaging it. `systemctl --user stop bb` frees the RAM, e.g.
# before Minecraft.
{ pkgs, lib, ... }:
let
  version = "0.48.1";
  npx = "${pkgs.nodejs_26}/bin/npx";

  bb = pkgs.writeShellScriptBin "bb" ''
    exec ${npx} -y --package bb-app@${version} bb "$@"
  '';

  syncPalette = pkgs.writeShellApplication {
    name = "bb-caelestia-sync";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      scheme="''${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json"
      [ -f "$scheme" ] || exit 0
      theme="''${BB_DATA_DIR:-$HOME/.bb}/theme/caelestia"
      python3 ${../../pkgs/bb-caelestia-theme.py} "$scheme" "$theme"
      # BB is already installed in npx's cache by its server service. A
      # colour switch must not contact npm or restart the running server.
      ${npx} --offline -y --package bb-app@${version} bb theme set caelestia
    '';
  };
in
{
  home.packages = [
    bb
    syncPalette
  ];

  home.activation.bbCaelestiaPalette = lib.hm.dag.entryAfter [ "caelestiaTemplates" ] ''
    run ${lib.getExe syncPalette} || true
  '';

  # A separate unit avoids changing/restarting bb.service during a rebuild.
  systemd.user.services.bb-caelestia-theme = {
    Unit = {
      Description = "Apply Caelestia's palette to BB";
      After = [ "bb.service" ];
      StartLimitIntervalSec = 30;
      StartLimitBurst = 5;
    };
    Install.WantedBy = [ "bb.service" ];
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe syncPalette;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.bb = {
    Unit = {
      Description = "bb server";
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      # The agents (`claude`, `opencode`) and git are found by bare name.
      Environment = [
        "PATH=${pkgs.nodejs_26}/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
        # Otherwise bb prefers ~/.local/bin/claude, where its "install Claude
        # Code" button drops Anthropic's generic binary -- which NixOS cannot
        # run ("Could not start dynamically linked executable").
        "BB_CLAUDE_CODE_EXECUTABLE=/etc/profiles/per-user/%u/bin/claude"
      ];
      # The LLM API keys (OpenRouter, MiniMax, ...) the shell gets from sops
      # (modules/sops.nix, templates."llm.env"); a user service does not
      # inherit the shell's environment, so opencode in bb had none.
      EnvironmentFile = "/run/secrets/rendered/llm.env";
      ExecStart = "${npx} -y --allow-scripts=better-sqlite3,node-pty,@parcel/watcher bb-app@${version} --no-in-app-updates";
      Restart = "on-failure";
    };
  };
}
