# AzPepoze's GUI for linux-wallpaperengine: a Go backend in the tray and an
# Electron window only while it is open. Upstream ships Linux builds as an
# AppImage and nothing else, and a source build would need both toolchains
# plus bun, so this wraps the release.
#
# The backend shells out by bare name, so what it calls has to be inside the
# FHS env: the engine itself, xrandr for the screens, killall to stop
# wallpapers, xprop for fullscreen pause, zenity for the folder picker and
# notify-send.
{
  lib,
  appimageTools,
  buildFHSEnv,
  fetchurl,
  linux-wallpaperengine,
}:
let
  pname = "linux-wallpaperengine-gui";
  version = "0.5.2";

  src = fetchurl {
    url = "https://github.com/AzPepoze/linux-wallpaperengine-gui/releases/download/v${version}/linux-wallpaperengine-gui.AppImage";
    hash = "sha256-UKURQDPH07WB/QlyFNOI6SEjPCP63Hg9a35pu48UPSM=";
  };

  contents = appimageTools.extract { inherit pname version src; };
in
buildFHSEnv (
  appimageTools.defaultFhsEnvArgs
  // {
    inherit pname version;

    targetPkgs =
      pkgs:
      appimageTools.defaultFhsEnvArgs.targetPkgs pkgs
      ++ [
        linux-wallpaperengine
        # The backend's tray icon; everything else it links is in the defaults.
        pkgs.libayatana-appindicator
        pkgs.xrandr
        pkgs.psmisc
        pkgs.xprop
        pkgs.zenity
        pkgs.libnotify
      ];

    runScript = "${contents}/resources/linux-wallpaperengine-gui";

    extraInstallCommands = ''
      install -Dm644 ${contents}/linux-wallpaperengine-gui.desktop $out/share/applications/linux-wallpaperengine-gui.desktop
      substituteInPlace $out/share/applications/linux-wallpaperengine-gui.desktop \
        --replace-fail 'Exec=AppRun --no-sandbox' 'Exec=linux-wallpaperengine-gui'
      install -Dm644 ${contents}/usr/share/icons/hicolor/512x512/apps/linux-wallpaperengine-gui.png \
        $out/share/icons/hicolor/512x512/apps/linux-wallpaperengine-gui.png
    '';

    meta = {
      description = "GUI for linux-wallpaperengine";
      homepage = "https://github.com/AzPepoze/linux-wallpaperengine-gui";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "linux-wallpaperengine-gui";
    };
  }
)
