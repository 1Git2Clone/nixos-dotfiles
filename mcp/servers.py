"""One catalog for all six agents, including the local proxy plumbing."""

from model import Http, Proxied, Server, Stdio


def servers(chrome_devtools_command: str) -> dict[str, Server]:
    return {
        "codebase-memory-mcp": Stdio("codebase-memory-mcp"),
        "chrome-devtools": Proxied(
            endpoint=Http("http://127.0.0.1:8932/servers/chrome-devtools/mcp"),
            process=Stdio(chrome_devtools_command),
        ),
        "dozzle": Http("https://dozzle.hu-tao.dev/api/mcp"),
        "openrouter-image": Proxied(
            endpoint=Http("http://127.0.0.1:8932/servers/openrouter-image/mcp"),
            process=Stdio("openrouter-image-mcp"),
        ),
        "playwright": Http("http://localhost:8931/mcp"),
        "sequential-thinking": Proxied(
            endpoint=Http("http://127.0.0.1:8932/servers/sequential-thinking/mcp"),
            process=Stdio("npx", args=("-y", "@gotza02/seq-thinking@1.3.5")),
        ),
    }
