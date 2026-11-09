"""Each provider implements the same small interface over typed transports."""

from abc import ABC, abstractmethod
from typing import Mapping, assert_never

from model import Http, Stdio, Transport

# Dictionaries exist only at the serialization boundary, never in the model.
type Json = None | bool | int | float | str | list[Json] | dict[str, Json]
type Object = dict[str, Json]


def stdio_fields(server: Stdio) -> Object:
    fields: Object = {"command": server.command}
    if server.args:
        fields["args"] = list(server.args)
    if server.env:
        fields["env"] = {key: value for key, value in server.env.items()}
    return fields


def http_fields(server: Http) -> Object:
    fields: Object = {"url": server.url}
    if server.headers:
        fields["headers"] = {key: value for key, value in server.headers.items()}
    return fields


class Provider(ABC):
    path: str
    section: str = "mcpServers"
    base: str | None = None

    @abstractmethod
    def encode(self, server: Transport) -> Object:
        """Translate one transport to this provider's native fields."""

    def render(self, servers: Mapping[str, Transport]) -> Object:
        entries: Object = {name: self.encode(server) for name, server in servers.items()}
        return {self.section: entries}


class Pi(Provider):
    path = ".pi/agent/mcp.json"

    def encode(self, server: Transport) -> Object:
        match server:
            case Stdio():
                return stdio_fields(server)
            case Http():
                return http_fields(server)
            case _:
                assert_never(server)


class Claude(Provider):
    path = ".claude/.mcp.json"

    def encode(self, server: Transport) -> Object:
        match server:
            case Http():
                return http_fields(server) | {"type": "http"}
            case Stdio():
                return stdio_fields(server)
            case _:
                assert_never(server)


class Cursor(Provider):
    path = ".cursor/mcp.json"

    def encode(self, server: Transport) -> Object:
        match server:
            case Stdio():
                return stdio_fields(server) | {"type": "stdio"}
            case Http():
                return http_fields(server)
            case _:
                assert_never(server)


class Codex(Provider):
    path = ".codex/config.toml"
    section = "mcp_servers"

    def encode(self, server: Transport) -> Object:
        match server:
            case Stdio():
                return stdio_fields(server)
            case Http():
                fields: Object = {"url": server.url}
                if server.headers:
                    fields["http_headers"] = {
                        key: value for key, value in server.headers.items()
                    }
                return fields
            case _:
                assert_never(server)


class Grok(Codex):
    path = ".grok/config.toml"
    base = "grok.toml"


class OpenCode(Provider):
    path = ".config/opencode/opencode.json"
    section = "mcp"
    base = "opencode.json"

    def encode(self, server: Transport) -> Object:
        match server:
            case Stdio():
                fields: Object = {
                    "type": "local",
                    "enabled": True,
                    "command": [server.command, *server.args],
                }
                if server.env:
                    fields["environment"] = {
                        key: value for key, value in server.env.items()
                    }
                return fields
            case Http():
                return http_fields(server) | {"type": "remote", "enabled": True}
            case _:
                assert_never(server)


PROVIDERS: tuple[Provider, ...] = (
    Claude(), Codex(), Cursor(), Grok(), OpenCode(), Pi(),
)
