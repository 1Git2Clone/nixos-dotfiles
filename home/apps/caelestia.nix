# The shell: its module, the schemes it switches between, the templates that
# recolour the desktop on every switch, and the state it expects to already
# exist.
{
  pkgs,
  lib,
  config,
  osConfig,
  inputs,
  palette,
  dotfiles,
  ...
}:
let
  cfg = config.hutao;
  inherit (config.xdg) stateHome;

  caelestiaScheme = (pkgs.formats.json { }).generate "caelestia-scheme.json" palette.schemeJson;

  caelestiaPkgs = inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system};

  qtFont = osConfig.stylix.fonts.monospace.name;
  qtFontSize = toString osConfig.stylix.fonts.sizes.applications;

  # The CLI lists schemes out of its own package and nowhere else -- not
  # ~/.config/caelestia/schemes -- so ours are copied in beside upstream's.
  #
  # Its qtengine template also hardcodes the Qt font (Sans Serif and
  # Monospace, 12), and the rendered config.json is rewritten on every
  # switch, so the template is where it changes. qtengine hands weight to
  # QFont as is: 300 is QFont::Light.
  cli =
    inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
      (old: {
        # Upstream's has no trailing newline.
        postInstall =
          (old.postInstall or "")
          + "\n"
          + ''
            data=$(echo $out/lib/python3*/site-packages/caelestia/data)
            cp -r ${../../dotfiles/caelestia/schemes}/. "$data/schemes/"
            substituteInPlace "$data/templates/qtengine.json" \
              --replace-fail '"family": "Sans Serif"' '"family": "${qtFont}"' \
              --replace-fail '"family": "Monospace"' '"family": "${qtFont}"' \
              --replace-fail '"size": 12' '"size": ${qtFontSize}' \
              --replace-fail '"weight": -1' '"weight": 300'
          '';
      });

  # caelestia's own template pass, redone for activation: a rebuild can
  # change a template without the scheme changing, and caelestia only renders
  # on a switch. Same fields and the same {{ key.form }} syntax, restricted to
  # the four forms palette.template writes.
  render =
    pkgs.writers.writePython3Bin "caelestia-render-templates"
      {
        flakeIgnore = [ "E501" ]; # 100 columns, not 79
      }
      ''
        import json
        import os
        import re
        from pathlib import Path

        home = Path.home()
        state = Path(os.environ.get("XDG_STATE_HOME") or home / ".local/state") / "caelestia"
        config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config") / "caelestia"

        scheme = json.loads((state / "scheme.json").read_text())
        colours = scheme["colours"]

        forms = {
            "hex": lambda c: c[:6],
            "red": lambda c: str(int(c[0:2], 16)),
            "green": lambda c: str(int(c[2:4], 16)),
            "blue": lambda c: str(int(c[4:6], 16)),
        }


        def fill(match):
            field = match.group(1).strip().split(".")
            if len(field) == 2 and field[0] in colours and field[1] in forms:
                return forms[field[1]](colours[field[0]])
            return match.group()


        out = state / "theme"
        out.mkdir(parents=True, exist_ok=True)
        for template in sorted((config / "templates").iterdir()):
            if not template.is_file():
                continue
            text = re.sub(r"\{\{((?:(?!\{\{|\}\}).)*)\}\}", fill, template.read_text())
            text = re.sub(r"\{\{\s*mode\s*\}\}", scheme["mode"], text)
            dest = out / template.name
            if dest.exists() and dest.read_text() == text:
                continue
            tmp = dest.with_name(dest.name + ".tmp")
            tmp.write_text(text)
            tmp.replace(dest)
      '';

  # caelestia's theme.postHook: run after every scheme switch, once its own
  # appliers and our templates are written, with the scheme in SCHEME_*.
  # Records the pick in the checkout so the next rebuild follows it, then
  # pokes every app that will not notice a rewritten file on its own.
  # Without SCHEME_NAME (activation) it only does the second half.
  hook = pkgs.writeShellApplication {
    name = "caelestia-theme-hook";
    runtimeInputs = [
      pkgs.jq
      pkgs.procps
      pkgs.diffutils
      pkgs.libnotify
    ];
    text = ''
      # Only rewrite a file whose content changed, so a re-applied scheme
      # leaves the checkout clean.
      put() {
        local tmp
        tmp=$(mktemp)
        cat > "$tmp"
        if cmp -s "$tmp" "$1"; then rm -f "$tmp"; else mv "$tmp" "$1"; fi
      }

      # The checkout, through the pointer rather than baked in, so a moved
      # clone is one edit to that file away from recording again.
      pointer="''${XDG_STATE_HOME:-$HOME/.local/state}/hutao/flake-path"
      if [ -n "''${SCHEME_NAME:-}" ]; then
        dir="$(cat "$pointer" 2> /dev/null || true)/dotfiles/caelestia"
        if [ -d "$dir" ]; then
          jq -n --arg name "$SCHEME_NAME" --arg flavour "$SCHEME_FLAVOUR" \
            --arg mode "$SCHEME_MODE" --arg variant "$SCHEME_VARIANT" \
            '{$name, $flavour, $mode, $variant}' | put "$dir/current.json"

          if [ "$SCHEME_NAME" = dynamic ]; then
            {
              echo "# Written by caelestia-theme-hook whenever the dynamic scheme is applied."
              jq -r 'keys_unsorted[] as $k | "\($k) \(.[$k])"' <<< "$SCHEME_COLOURS"
            } | put "$dir/dynamic.txt"
          fi
        else
          notify-send -a caelestia "Scheme not recorded" \
            "No checkout at $dir; set hutao.flakePath or edit $pointer." || true
        fi
      fi

      # Best-effort, each: an app that is not running has nothing to reload.
      pkill -USR1 -x kitty || true
      pkill -USR2 -x waybar || true
      if command -v makoctl > /dev/null; then makoctl reload || true; fi
      if command -v tmux-apply-colors.sh > /dev/null && tmux has-session 2> /dev/null; then
        tmux-apply-colors.sh || true
      fi
      # Only with a session: activation runs its own reload in hyprland.nix.
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then hyprctl reload > /dev/null || true; fi
      # Vencord re-reads its themes on any event in their directory, and the
      # rewrite lands behind the symlinks, outside it.
      touch -ch "${config.xdg.configHome}"/vesktop/themes/*.theme.css 2> /dev/null || true
    '';
  };
in
{
  options.hutao = {
    flakePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Projects/nixos-dotfiles";
      description = ''
        The checkout of this flake, where caelestia-theme-hook records the
        picked scheme. Not derivable: a flake is evaluated from its copy in
        the store, and `self` points there. Published to the hook as
        $XDG_STATE_HOME/hutao/flake-path.
      '';
    };

    caelestiaTemplates = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.path;
              description = "The template, with palette.template's fields for colours.";
            };
            target = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path under $HOME that links to the rendered file, if any.";
            };
          };
        }
      );
      default = { };
      description = ''
        caelestia user templates, by file name. caelestia renders each into
        $XDG_STATE_HOME/caelestia/theme on every scheme switch, which is what
        lets an app recolour without a rebuild.
      '';
    };
  };

  config = {
    programs.caelestia = {
      enable = true;
      # Without the CLI bundled in: that copy would come first on the shell's
      # PATH and list only upstream's schemes, and rebuilding the shell for
      # every scheme edit is a C++ build. The shell finds `cli` below on PATH.
      package = caelestiaPkgs.default;
      cli.enable = true;
      cli.package = cli;
      # autostart.lua already execs it; true here double-starts.
      systemd.enable = false;
      # shell.json is gitignored upstream, so it is vendored here.
      extraConfig = builtins.readFile ../caelestia-shell.json;
    };

    # The CLI reads cli.json; extraConfig above is the shell's shell.json, and
    # the two are separate files. `caelestia record` passes no -a unless it is
    # given --sound, and --sound is hardcoded to default_output -- the speakers.
    # Nothing in it ever records a microphone, so the mic goes in here.
    #
    # One -a, sources merged with `|`, so both land on a single track: repeating
    # -a makes a track each, and most players only ever play the first. Drop
    # `default_output|` for a mic-only recording.
    #
    # theme: caelestia owns gtk and qt, and recolours both on every switch.
    # Off are the appliers something here already does better: kitty re-reads
    # mocha.conf on the hook's USR1, where enableTerm would paint caelestia's own
    # terminal mapping over it; Hyprland takes its colours from a template;
    # vesktop's caelestia.theme.css is ours, a template too. iconTheme, or it
    # sets Papirus-Dark over the folders.
    xdg.configFile."caelestia/cli.json".text = builtins.toJSON {
      record.extraArgs = [
        "-a"
        "default_output|default_input"
      ];
      theme = {
        enableTerm = false;
        enableHypr = false;
        enableDiscord = false;
        iconTheme = config.gtk.iconTheme.name;
        postHook = lib.getExe hook;
      };
    };

    xdg.configFile = {
      # caelestia creates these itself, but after Hyprland reads its config.
      "caelestia/hypr-user.conf".text = "";
      "caelestia/hypr-vars.conf".text = "";
    };

    xdg.stateFile."hutao/flake-path".text = cfg.flakePath;

    # The template into caelestia's templates dir, and the app's path to what
    # caelestia renders from it -- into $XDG_STATE_HOME, not the store, since
    # the rendered file is the one that changes on a switch.
    home.file = lib.concatMapAttrs (
      name: t:
      {
        "${config.xdg.configHome}/caelestia/templates/${name}".source = t.source;
      }
      // lib.optionalAttrs (t.target != null) {
        ${t.target}.source = config.lib.file.mkOutOfStoreSymlink "${stateHome}/caelestia/theme/${name}";
      }
    ) cfg.caelestiaTemplates;

    # Before hyprlandReload, which is what re-reads Hyprland's colours; after
    # linkGeneration, which is what puts the templates in place.
    home.activation.caelestiaTemplates =
      lib.hm.dag.entryBetween [ "hyprlandReload" ] [ "linkGeneration" "caelestiaScheme" ]
        ''
          run ${lib.getExe render}
          run ${lib.getExe hook} || true
        '';

    # caelestia's face picker writes to ~/.face, so seed it.
    home.activation.face = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${config.home.homeDirectory}/.face" ]; then
        run cp -L ${dotfiles}/dot-config/fastfetch/icons/HuTaoSmall.png \
          "${config.home.homeDirectory}/.face"
        run chmod u+w "${config.home.homeDirectory}/.face"
      fi
    '';

    # Personal data that is not in the repo, so a fresh machine starts empty.
    home.activation.wallpapers =
      let
        dir = "${config.home.homeDirectory}/Pictures/Wallpapers";
        state = "${config.xdg.stateHome}/caelestia/wallpaper";
        # `caelestia wallpaper` rewrites both.
        current = "${dir}/Hu_Tao_00056_1.png";
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e "${dir}" ]; then
          run mkdir -p "${dir}"
          run cp -L ${dotfiles}/dot-config/hypr/backgrounds/* "${dir}"/
          run chmod u+w "${dir}"/*
        fi

        if [ ! -e "${state}/path.txt" ]; then
          run mkdir -p "${state}"
          run ln -sfn "${current}" "${state}/current"
          printf '%s\n' "${current}" > "${state}/path.txt"
        fi
      '';

    # The shell is a Qt process that caches every icon lookup it makes, and it
    # resolves them out of whichever profile held app-icons when it started.
    # Moving that package between environment.systemPackages and home.packages
    # therefore breaks the launcher's icons in a live session and nothing short
    # of a restart fixes it -- the files are correct, the process is not. There
    # is no reload in the shell's IPC (`caelestia shell -s`), so it has to be
    # killed and started again.
    #
    # The switch runs outside the session, with QT_QPA_PLATFORM=offscreen
    # among other things, so a shell started from here comes up with no
    # display and none of its services. Hyprland starts it instead, with the
    # session's environment and autostart's own command (programs.shell), read
    # fresh through `hyprctl eval`: dofile, not require, which could hand back
    # the module cached from before this switch.
    # Best-effort throughout: no shell running, nothing to do, and a failure
    # here must not fail the switch.
    #
    # No -x: the process being looked for is quickshell-wrapped's
    # `.quickshell-wrapped`, and a comm is 15 characters, so what /proc actually
    # holds is `.quickshell-wra` and an exact match never hit. -f would match,
    # but the activation script's own command line contains the pattern too.
    home.activation.caelestiaReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      pid=$(${pkgs.procps}/bin/pgrep -u "$UID" quickshell 2>/dev/null | head -1 || true)
      if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
        sig=$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p' | head -1)
        if [ -n "$sig" ]; then
          # The CLI finds caelestia-shell on PATH, which activation's lacks.
          run env PATH="${config.programs.caelestia.package}/bin:$PATH" \
            ${cli}/bin/caelestia shell -k || true
          run ${osConfig.programs.hyprland.package}/bin/hyprctl -i "$sig" \
            eval 'hl.exec_cmd(dofile("${config.xdg.configHome}/hypr/modules/programs.lua").shell)' || true
        fi
      fi
    '';

    home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      state="${config.xdg.stateHome}/caelestia"
      if [ ! -e "$state/scheme.json" ]; then
        run mkdir -p "$state"
        run install -m600 ${caelestiaScheme} "$state/scheme.json"
      fi
    '';
  };
}
