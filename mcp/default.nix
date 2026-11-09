{ pkgs, chromeDevtoolsCommand }:
let
  python = pkgs.python3.withPackages (ps: [ ps.tomli-w ]);
in
pkgs.runCommand "agent-mcp-configs" { nativeBuildInputs = [ python ]; } ''
  python ${./.}/render.py ${pkgs.lib.escapeShellArg chromeDevtoolsCommand} $out
''
