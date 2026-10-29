# bb, an agentic IDE that drives the coding agents already installed (Claude
# Code and opencode here). Upstream's Linux build is an alpha AppImage; the
# source build is a bun/Electron monorepo, so this wraps the release.
#
# bb finds the agents by bare name on PATH, and the FHS env keeps the host's
# PATH and /nix, so the `claude` and `opencode` from the home profile resolve
# as they do in a terminal.
{
  lib,
  appimageTools,
  fetchurl,
}:
let
  pname = "bb";
  version = "0.48.0";

  src = fetchurl {
    url = "https://github.com/get-bb/bb/releases/download/desktop-v${version}/bb-${version}-x86_64.AppImage";
    hash = "sha256-5ObRSMupvO8ggEhwkFeWzxQoh48RAx7qQWGLg0Lgoqo=";
  };

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    desktop=$(find ${contents} -maxdepth 1 -name '*.desktop' | head -1)
    install -Dm644 "$desktop" $out/share/applications/bb.desktop
    sed -i -E 's|^Exec=[^ ]+|Exec=bb|' $out/share/applications/bb.desktop
    icon=$(find ${contents} -maxdepth 1 -name '*.png' | head -1)
    [ -n "$icon" ] && install -Dm644 "$icon" $out/share/icons/hicolor/512x512/apps/bb.png
  '';

  meta = {
    description = "Agentic IDE that drives Claude Code, opencode and other agents";
    homepage = "https://getbb.app/";
    license = lib.licenses.mit;
    mainProgram = "bb";
    platforms = [ "x86_64-linux" ];
  };
}
