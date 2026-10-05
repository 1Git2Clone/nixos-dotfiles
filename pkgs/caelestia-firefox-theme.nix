# CaelestiaFox's native half. The extension from AMO does nothing on its own:
# it recolours the browser from whatever this sends, which is scheme.json on
# start and again on every switch. Upstream only ships it as an Arch package
# (packages/caelestia-firefox-theme/PKGBUILD), so this follows that package's
# names and layout. The manifest's /usr path is the one change Nix needs.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  fish,
  jq,
  inotify-tools,
}:
stdenvNoCC.mkDerivation {
  pname = "caelestia-firefox-theme";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "caelestia-dots";
    repo = "caelestia";
    rev = "d459e9182ae55ba7eb29fa90781297224911d6bd";
    sparseCheckout = [ "firefox/native_app" ];
    hash = "sha256-r1E0hYzKZWssaOA1JzZwvWXLDhTn5u2uRtDKeA237z4=";
  };

  nativeBuildInputs = [ makeWrapper ];
  # For patchShebangs, which resolves app.fish's `env fish` against these.
  buildInputs = [ fish ];

  installPhase = ''
    install -Dm644 firefox/native_app/manifest.json $out/lib/mozilla/native-messaging-hosts/caelestiafox.json
    install -Dm755 firefox/native_app/app.fish $out/lib/caelestia/caelestiafox

    substituteInPlace $out/lib/mozilla/native-messaging-hosts/caelestiafox.json \
      --replace-fail /usr/lib/caelestia/caelestiafox $out/lib/caelestia/caelestiafox
    wrapProgram $out/lib/caelestia/caelestiafox \
      --prefix PATH : ${
        lib.makeBinPath [
          jq
          inotify-tools
        ]
      }
  '';

  meta = {
    description = "The native app component of the CaelestiaFox Firefox theme";
    longDescription = ''
      Install the extension itself from
      https://addons.mozilla.org/en-US/firefox/addon/caelestiafox.
    '';
    homepage = "https://github.com/caelestia-dots/caelestia";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
