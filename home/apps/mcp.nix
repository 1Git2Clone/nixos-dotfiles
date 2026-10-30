# The MCP servers, run once each as user services that every agent shares over
# HTTP. As stdio servers each opencode instance (bb's, a TUI's, `opencode
# run`'s) started its own copy of all of them, ~290M a time (measured
# 2026-10-29).
#
# playwright serves HTTP itself, with a browser context per client, so two
# agents never drive the same tab. The other two are stdio-only, so mcp-proxy
# fronts them, at http://127.0.0.1:8932/servers/<name>/mcp. codebase-memory-mcp
# stays stdio: it is 15M and indexes the project it is started in. Every
# harness (Claude Code, Codex, Cursor, Grok, OpenCode, Pi) points here.
{ lib, pkgs, ... }:
let
  chrome-devtools-mcp = pkgs.callPackage ../../pkgs/chrome-devtools-mcp.nix { };

  path = "PATH=${pkgs.nodejs_26}/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";

  servers = pkgs.writeText "mcp-servers.json" (
    builtins.toJSON {
      mcpServers = {
        sequential-thinking = {
          command = "npx";
          args = [
            "-y"
            "@gotza02/seq-thinking@1.3.5"
          ];
        };
        openrouter-image.command = "openrouter-image-mcp";
        # One browser and one selected page for every agent, unlike
        # playwright's context per client: agents driving it at once share it.
        chrome-devtools.command = lib.getExe chrome-devtools-mcp;
      };
    }
  );

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
  systemd.user.services.mcp-playwright = service "Playwright MCP server" "/etc/profiles/per-user/%u/bin/playwright-mcp --port 8931 --isolated";

  systemd.user.services.mcp-proxy = service "MCP proxy for the stdio servers" "${pkgs.mcp-proxy}/bin/mcp-proxy --port 8932 --pass-environment --named-server-config ${servers}";
}
