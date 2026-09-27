# Spotify with spicetify: the marketplace, and caelestia's theme recoloured
# live on every scheme switch.
#
# spicetify patches Spotify's Apps directory in place, and the store copy is
# read-only. Spotify takes --app-directory, so the wrapper below points it at
# a writable copy in $XDG_DATA_HOME, and spicetify's spotify_path is a
# directory holding that copy plus the one store file it reads
# (v8_context_snapshot.bin). The rest of Spotify stays in the store.
#
# caelestia writes Themes/caelestia/color.ini on every switch (its
# enableSpicetify applier), caelestia-theme-hook runs `spicetify refresh` to
# turn it into colors.css, and theme.js re-links that file in the running
# client.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (pkgs) spotify spicetify-cli;

  spotifyDir = "${config.xdg.dataHome}/spotify-spicetify";
  appsDir = "${spotifyDir}/Apps";
  themeDir = "${config.xdg.configHome}/spicetify/Themes/caelestia";
  prefs = "${config.xdg.configHome}/spotify/prefs";

  wrapped = pkgs.symlinkJoin {
    name = "spotify-spicetify";
    paths = [ spotify ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/spotify --add-flags "--app-directory=${appsDir}"
    '';
  };

  marketplace = pkgs.fetchzip {
    url = "https://github.com/spicetify/marketplace/releases/download/v1.0.11/marketplace.zip";
    hash = "sha256-6bSL/Vo/GPAVDAO6G2fxYdiMVitG3Xxka0oD+HL0wBE=";
  };

  # caelestia's own theme, from the dots repo the CLI's colours are meant for.
  userCss = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/caelestia-dots/caelestia/2d55cc3a845788682404f81c5cc1faeec97a553b/spicetify/Themes/caelestia/user.css";
    hash = "sha256-qfIz6aPQf+W+kMhnWVe67q7JkQPM/kTNw1eLH2XdxJo=";
  };

  cli = config.programs.caelestia.cli.package;

  # Everything a patched Apps is built from. A change re-copies it from the
  # store and re-applies; anything else leaves a running Spotify alone.
  sources = lib.concatStringsSep " " [
    spotify
    spicetify-cli
    marketplace
    userCss
    ../spicetify-theme.js
  ];
in
{
  home.packages = [
    wrapped
    spicetify-cli
  ];

  xdg.configFile = {
    "spicetify/CustomApps/marketplace".source = marketplace;
    "spicetify/Themes/caelestia/user.css".source = userCss;
    "spicetify/Themes/caelestia/theme.js".source = ../spicetify-theme.js;
  };

  home.file = {
    "${spotifyDir}/v8_context_snapshot.bin".source = "${spotify}/share/spotify/v8_context_snapshot.bin";
    # For `spicetify restart`, which runs spotify_path/spotify.
    "${spotifyDir}/spotify".source = "${wrapped}/bin/spotify";
  };

  # config-xpui.ini is spicetify's to write -- `backup` records the Spotify
  # version in it -- so it is edited here rather than linked from the store.
  #
  # The backup is only valid while prefs' app.last-launched-version matches
  # the version it was taken at, and Spotify writes that on launch. It is set
  # to the store's version ahead of that launch, and a mismatch (a Spotify
  # that was still running when this switched) re-applies next time.
  home.activation.spicetify =
    lib.hm.dag.entryAfter [ "linkGeneration" "caelestiaScheme" "caelestiaTemplates" ]
      ''
        # caelestia only writes color.ini on a switch, so a fresh home seeds
        # it from the current scheme with the CLI's own template.
        if [ ! -e "${themeDir}/color.ini" ]; then
          scheme="${config.xdg.stateHome}/caelestia/scheme.json"
          template=$(echo ${cli}/lib/python3*/site-packages/caelestia/data/templates/spicetify-"$(${pkgs.jq}/bin/jq -r .mode "$scheme")".ini)
          ${pkgs.jq}/bin/jq -r --rawfile t "$template" \
            '.colours | reduce to_entries[] as $e ($t; gsub("\\{\\{ \\$" + $e.key + " \\}\\}"; $e.value))' \
            "$scheme" > "${themeDir}/color.ini"
        fi

        version='app.last-launched-version="${spotify.version}"'
        if [ "$(cat "${spotifyDir}/stamp" 2> /dev/null)" != "${sources}" ] \
          || ! grep -qxF "$version" "${prefs}" 2> /dev/null; then
          run mkdir -p "$(dirname "${prefs}")"
          run touch "${prefs}"
          run sed -i '/^app\.last-launched-version=/d' "${prefs}"
          echo "$version" >> "${prefs}"

          run rm -rf "${appsDir}"
          run cp -r --no-preserve=mode ${spotify}/share/spotify/Apps "${appsDir}"

          run ${lib.getExe spicetify-cli} -q config \
            spotify_path "${spotifyDir}" \
            prefs_path "${prefs}" \
            current_theme caelestia \
            color_scheme caelestia \
            custom_apps marketplace \
            check_spicetify_update 0
          # -n: never kill a running Spotify from a rebuild.
          run ${lib.getExe spicetify-cli} -q -n backup apply
          echo "${sources}" > "${spotifyDir}/stamp"
        fi
      '';
}
