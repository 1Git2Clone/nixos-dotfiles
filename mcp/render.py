"""Build the six native configs and the local proxy's launch configuration."""

import json
import sys
import tomllib
from pathlib import Path

import tomli_w

from model import Proxied, Transport
from providers import PROVIDERS, Object, stdio_fields
from servers import servers


def write(path: Path, data: Object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = tomli_w.dumps(data) if path.suffix == ".toml" else json.dumps(data, indent=2) + "\n"
    path.write_text(text)


def main(chrome_devtools_command: str, output: Path) -> None:
    catalog = servers(chrome_devtools_command)
    transports: dict[str, Transport] = {}
    processes: Object = {}
    for name, server in catalog.items():
        if isinstance(server, Proxied):
            transports[name] = server.endpoint
            processes[name] = stdio_fields(server.process)
        else:
            transports[name] = server

    for provider in PROVIDERS:
        base: Object = {}
        if provider.base:
            path = Path(__file__).parent / "bases" / provider.base
            base = tomllib.loads(path.read_text()) if path.suffix == ".toml" else json.loads(path.read_text())
        write(output / provider.path, base | provider.render(transports))
    write(output / "proxy.json", {"mcpServers": processes})


if __name__ == "__main__":
    main(sys.argv[1], Path(sys.argv[2]))
