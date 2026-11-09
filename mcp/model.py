"""The complete MCP model: a transport, optionally served by a local proxy."""

from dataclasses import dataclass, field
from typing import Mapping


@dataclass(frozen=True)
class Stdio:
    command: str
    args: tuple[str, ...] = ()
    env: Mapping[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class Http:
    url: str
    headers: Mapping[str, str] = field(default_factory=dict)


type Transport = Stdio | Http


@dataclass(frozen=True)
class Proxied:
    endpoint: Http
    process: Stdio


type Server = Transport | Proxied
