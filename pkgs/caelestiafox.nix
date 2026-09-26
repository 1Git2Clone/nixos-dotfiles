# CaelestiaFox's native half. The extension from AMO does nothing on its own:
# it recolours the browser from whatever this sends, which is scheme.json on
# start and again on every switch. Upstream only ships it in an Arch package,
# so this is that package: the script, and the manifest the browser finds it
# by, under lib/mozilla/native-messaging-hosts for a wrapper's
# nativeMessagingHosts.
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
  pname = "caelestiafox";
  version = "0-unstable-2026-09-22";

  src = fetchFromGitHub {
    owner = "caelestia-dots";
    repo = "caelestia";
    rev = "d459e9182ae55ba7eb29fa90781297224911d6bd";
    sparseCheckout = [ "firefox/native_app" ];
    hash = "sha256-r1E0hYzKZWssaOA1JzZwvWXLDhTn5u2uRtDKeA237z4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -Dm755 firefox/native_app/app.fish $out/libexec/caelestiafox.fish
    makeWrapper ${lib.getExe fish} $out/bin/caelestiafox \
      --add-flags $out/libexec/caelestiafox.fish \
      --prefix PATH : ${
        lib.makeBinPath [
          jq
          inotify-tools
        ]
      }

    ${lib.getExe jq} --arg path $out/bin/caelestiafox '.path = $path' \
      firefox/native_app/manifest.json \
      | install -Dm644 /dev/stdin $out/lib/mozilla/native-messaging-hosts/caelestiafox.json
  '';

  meta = {
    description = "Native app for the CaelestiaFox extension";
    homepage = "https://github.com/caelestia-dots/caelestia";
    license = lib.licenses.gpl3Only;
    mainProgram = "caelestiafox";
  };
}
