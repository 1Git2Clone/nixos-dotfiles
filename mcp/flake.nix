{
  description = "Shared MCP definitions and configuration generators for six agents";

  # The caller supplies its pinned pkgs; no second nixpkgs lock to maintain.
  outputs = _: {
    lib = {
      mkConfigs = import ./default.nix;
      paths = [
        ".claude/.mcp.json"
        ".codex/config.toml"
        ".cursor/mcp.json"
        ".grok/config.toml"
        ".config/opencode/opencode.json"
        ".pi/agent/mcp.json"
      ];
    };
  };
}
