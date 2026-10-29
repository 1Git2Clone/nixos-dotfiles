# xAI's Grok Build CLI, the `grok` bb drives -- not nixpkgs' grok-cli, an
# unrelated community tool under the same name. xAI ships it as one
# static-pie binary (https://x.ai/cli/install.sh), so it runs as downloaded.
# Latest version: `curl -fsSL https://x.ai/cli/stable`.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "grok";
  version = "1.0.70";

  src = fetchurl {
    url = "https://x.ai/cli/grok-${version}-linux-x86_64";
    hash = "sha256-ItKBxZZMVEQUcygJa6KiIfPwh0xoWOJ8glZWqA9uWOk=";
  };

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    install -Dm755 $src $out/bin/grok
  '';

  meta = {
    description = "xAI's Grok Build coding agent CLI";
    homepage = "https://x.ai/cli";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "grok";
  };
}
