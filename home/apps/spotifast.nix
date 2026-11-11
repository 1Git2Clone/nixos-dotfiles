{
  pkgs,
  lib,
  config,
  palette,
  ...
}:
let
  inherit (palette.template) hex;
  app = pkgs.callPackage ../../pkgs/spotifast { };
  sync = pkgs.writeShellApplication {
    name = "spotifast-caelestia-sync";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      source="${config.xdg.stateHome}/caelestia/theme/spotifast-theme.json"
      dest="${config.xdg.configHome}/spotifast/themes"
      if [ ! -f "$source" ]; then exit 0; fi
      mkdir -p "$dest"
      tmp=$(mktemp "$dest/.caelestia.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      jq --slurpfile scheme "${config.xdg.stateHome}/caelestia/scheme.json" \
        '.base = $scheme[0].mode' "$source" > "$tmp"
      chmod 600 "$tmp"
      mv "$tmp" "$dest/Caelestia.json"
    '';
  };
  configure = pkgs.writeShellApplication {
    name = "spotifast-configure";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      ${lib.getExe sync}
      dir="${config.xdg.configHome}/spotifast"
      mkdir -p "$dir"
      settings="$dir/settings.json"
      input="$settings"
      if [ ! -f "$input" ]; then input=${pkgs.writeText "spotifast-defaults.json" "{}"}; fi
      tmp=$(mktemp "$dir/.settings.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      jq '.custom_theme = "Caelestia.json" | .accent_from_art = false | .keep_playing_in_background = false' \
        "$input" > "$tmp"
      chmod 600 "$tmp"
      mv "$tmp" "$settings"
    '';
  };
  package = pkgs.symlinkJoin {
    name = "spotifast-caelestia";
    paths = [ app ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/spotifast"
      # Soloist is downloaded and executed by Spotifast, including a version
      # check during installation. Give both processes an FHS runtime.
      makeWrapper ${lib.getExe pkgs.steam-run} "$out/bin/spotifast" \
        --add-flags ${lib.getExe app} \
        --prefix XDG_DATA_DIRS : ${pkgs.noto-fonts-cjk-sans}/share \
        --run ${lib.escapeShellArg (lib.getExe configure)}
    '';
  };
in
{
  home.packages = [ package sync ];

  hutao.caelestiaTemplates."spotifast-theme.json".source =
    (pkgs.formats.json { }).generate "spotifast-theme.json" {
      base = palette.mode;
      colors = {
        window = hex.base;
        panel = hex.mantle;
        surface = hex.surface0;
        surface_hover = hex.surface1;
        surface_active = hex.surface2;
        inherit (hex) outline text;
        secondary = hex.subtext1;
        dim = hex.subtext0;
        accent = hex.primary;
        accent_hover = hex.primaryContainer;
        on_accent = hex.onPrimary;
        danger = hex.error;
        warning = hex.yellow;
      };
    };
}
