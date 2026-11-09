# The MCP servers, run once each as user services that every agent shares over
# HTTP. As stdio servers each opencode instance (bb's, a TUI's, `opencode
# run`'s) started its own copy of all of them, ~290M a time (measured
# 2026-10-29).
#
# playwright serves HTTP itself, with a browser context per client, so two
# agents never drive the same tab. Three others are stdio-only, so mcp-proxy
# fronts them, at http://127.0.0.1:8932/servers/<name>/mcp. codebase-memory-mcp
# stays stdio: it is 15M and indexes the project it is started in. Every
# harness (Claude Code, Codex, Cursor, Grok, OpenCode, Pi) points here.
# mcp/servers.py also declares remote endpoints; see docs/src/architecture/mcp.md.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  configs = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.mcp-configs;

  path = "PATH=${pkgs.nodejs_26}/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";

  service = description: exec: {
    Unit = {
      Description = description;
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Environment = path;
      # OPENROUTER_API_KEY, for openrouter-image (modules/sops.nix).
      EnvironmentFile = "/run/secrets/rendered/llm.env";
      ExecStart = exec;
      Restart = "on-failure";
    };
  };
in
{
  # Same home paths and store symlinks as the old tracked agent configs.
  home.file = lib.genAttrs inputs.mcp-config.lib.paths (path: {
    source = "${configs}/${path}";
  });

  systemd.user.services.mcp-playwright = service "Playwright MCP server" "/etc/profiles/per-user/%u/bin/playwright-mcp --port 8931 --isolated";

  systemd.user.services.mcp-proxy = service "MCP proxy for the stdio servers" "${pkgs.mcp-proxy}/bin/mcp-proxy --port 8932 --pass-environment --named-server-config ${configs}/proxy.json";
}
