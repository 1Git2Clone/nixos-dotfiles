# Upstream binaries only. The FHS environment also covers the programs the
# launcher starts (game, preparation, and Mojang's Java), without patching them.
{
  lib,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
  writeShellScript,
  makeDesktopItem,
}:
let
  gameVersion = "nightly-2026-10-30";
  launcherVersion = "0.2.29";
  game = stdenvNoCC.mkDerivation {
    pname = "horizon-game-bin";
    version = gameVersion;
    src = fetchurl {
      url = "https://github.com/horizon-rust/horizon/releases/download/${gameVersion}/horizon-linux-x86_64.tar.gz";
      hash = "sha256-DW1EgAB5rPJRTF4OamDHxuPIygcMaZCyRXqSWDiyTU4=";
    };
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };
  launcher = stdenvNoCC.mkDerivation {
    pname = "horizon-launcher-bin";
    version = launcherVersion;
    src = fetchurl {
      url = "https://github.com/horizon-rust/horizon/releases/download/launcher%40${launcherVersion}/horizon-launcher-linux-x86_64.tar.gz";
      hash = "sha256-ZUQ2MxRyf5KLBK88r+uNJa2+FU4y3ywDPTekyUcC7Kc=";
    };
    sourceRoot = ".";
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      install -Dm755 horizon-launcher $out/bin/horizon-launcher
    '';
  };
  desktop = makeDesktopItem {
    name = "horizon-nixos";
    desktopName = "Horizon Minecraft 26.3";
    comment = "Horizon client and Microsoft sign-in (Nix-pinned release)";
    exec = "horizon-launcher";
    icon = "applications-games";
    categories = [ "Game" ];
  };
  start = writeShellScript "horizon-start" ''
    set -euo pipefail
    umask 077
    export HORIZON_LAUNCHER_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/horizon-launcher-nixos"
    export HORIZON_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/horizon-nixos"
    export HORIZON_LAUNCHER_NO_SELF_UPDATE=1
    mkdir -p "$HORIZON_LAUNCHER_HOME/versions" "$HORIZON_HOME"
    version="$HORIZON_LAUNCHER_HOME/versions/${gameVersion}"
    (
      flock 9
      if [ ! -f "$version/.nix-source" ] || [ "$(cat "$version/.nix-source")" != '${game}' ]; then
        mkdir -p "$version"
        # Only upstream files are refreshed; private prepared resources stay.
        cp -r --no-preserve=mode ${game}/. "$version/"
        printf '%s\n' '${game}' > "$version/.nix-source"
        touch "$version/.installed"
      fi
      # cp under a private umask deliberately drops source permissions.
      chmod u+x "$version"/horizon-{client,ctl,prepare,server}
      python3 ${./settings.py} '${gameVersion}'
    ) 9> "$HORIZON_LAUNCHER_HOME/.nix-init.lock"
    if [ "''${1:-}" = --nix-command ]; then
      shift
      command="$1"
      shift
      exec "$version/$command" "$@"
    fi
    exec ${launcher}/bin/horizon-launcher "$@"
  '';
in
buildFHSEnv {
  pname = "horizon-launcher";
  version = launcherVersion;
  targetPkgs =
    pkgs: with pkgs; [
      alsa-lib
      bash
      cacert
      coreutils
      curl
      dbus
      fontconfig
      freetype
      jdk25
      libGL
      libsecret
      libx11
      libxcb
      libxcursor
      libxi
      libxkbcommon
      libxrandr
      openssl
      python3
      stdenv.cc.cc.lib
      udev
      util-linux
      vulkan-loader
      wayland
      xdg-utils
      zlib
    ];
  runScript = start;
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${desktop}/share/applications/* $out/share/applications/
    for command in horizon-prepare horizon-ctl; do
      cat > "$out/bin/$command" <<SCRIPT
    #!${stdenvNoCC.shell}
    exec "$out/bin/horizon-launcher" --nix-command "$command" "\$@"
    SCRIPT
      chmod +x "$out/bin/$command"
    done
  '';
  meta = {
    description = "Horizon Minecraft 26.3 client with pinned game and launcher binaries";
    homepage = "https://playhorizon.dev";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "horizon-launcher";
  };
}
