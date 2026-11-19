# MCP servers

The shared catalog in `mcp/servers.py` configures Claude Code, Codex, Cursor,
Grok Build, OpenCode and Pi, including Dozzle. Add a server there once to
include it in all six agents.

## The Python project

- `model.py`: `Stdio(command, args, env)`, `Http(url, headers)` and
  `Proxied(endpoint, process)`. A proxied server exposes an HTTP endpoint to
  clients and starts a stdio process through the local proxy.
- `servers.py`: the catalog, built directly from those types.
- `providers.py`: the `Provider.encode(Transport)` interface and six adapters.
  Grok inherits Codex's format; other adapters specify their native fields.
- `render.py`: separates endpoints from proxy processes, applies the adapters,
  preserves the settings in `bases/`, and writes JSON or TOML.

For example, a remote server needs only:

```python
"dozzle": Http("https://dozzle.hu-tao.dev/api/mcp"),
```

The existing local services keep their commands and ports. Playwright serves
HTTP on `localhost:8931` (IPv6), with isolated browser contexts. The three
`Proxied` entries feed `proxy.json`, served by `mcp-proxy` on port 8932 at
`/servers/<name>/mcp`. Only codebase-memory-mcp starts separately per agent.
Chrome-devtools shares one browser and selected page across clients.

Do not put credentials in the catalog: generated files enter the Nix store.
The local services still read `/run/secrets/rendered/llm.env` for the image
server's API key.

## Nix and home paths

The local `mcp/flake.nix` exposes `lib.mkConfigs`. The root flake supplies its
pinned Python packages and chrome-devtools executable; Nix builds the files,
and `home/apps/mcp.nix` links them through Home Manager. No activation merge
or additional MCP-specific CI hook is involved.

`pkgs/chrome-devtools-mcp.nix` wraps the prebuilt npm release with Node.
2026-11-19: release 1.13.0 moved its bundled JavaScript from `build/` to
`out/Default/gen/src/`; both the copied directory and wrapper entry point must
follow that layout when updating the pin.

| Agent | Home path |
| ----- | --------- |
| Claude Code | `~/.claude/.mcp.json` |
| Codex | `~/.codex/config.toml` |
| Cursor | `~/.cursor/mcp.json` |
| Grok Build | `~/.grok/config.toml` |
| OpenCode | `~/.config/opencode/opencode.json` |
| Pi | `~/.pi/agent/mcp.json` |

These remain read-only store symlinks inside writable directories. Codex's
trust-file behavior is unchanged. Claude's existing wrapper passes
`--mcp-config ~/.claude/.mcp.json`; Pi uses its built-in MCP extension.
BB's plugin-provided tools are separate.

Preview the generated files with `nix build .#mcp-configs`, then inspect
`result/.claude/.mcp.json` or the other paths above. A normal system rebuild
installs them. The repository checks remain
`nix develop -c pre-commit run --all-files`.

## Dozzle and OAuth

Enable `DOZZLE_ENABLE_MCP=true` on Dozzle. With simple auth or OIDC, use each
client's OAuth flow, such as Claude's `/mcp` menu. Clients authenticate
separately and store their own tokens outside the generated configuration.
See [Dozzle's MCP guide](https://dozzle.dev/guide/mcp).

On 2026-11-08, `https://dozzle.hu-tao.dev/api/mcp` returned HTTP 404 for an
MCP initialize request. Enable and expose that endpoint before authenticating.
