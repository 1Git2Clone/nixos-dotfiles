# `stow --dotfiles` as a derivation: same tree, same dot-foo -> .foo renaming,
# same ignore file, but every path lands in the store.
#
# So ~/.config is read-only, and a dotfiles change needs
# `nix flake update dotfiles`. To iterate without pushing, swap `src` for
#   config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles"
{
  inputs,
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:
let
  # Walked with readDir — a plain path, so no import-from-derivation. `df` is
  # what actually gets linked.
  src = inputs.dotfiles;

  inherit (osConfig.networking) hostName;

  # --replace-fail on purpose: when a patch lands upstream the build breaks
  # instead of silently doing nothing.
  df = pkgs.runCommandLocal "hutao-dotfiles-${hostName}" { } ''
    cp -r ${src} $out
    chmod -R u+w $out

    # `command`, not a path, so the wrapper still shadows itself.
    substituteInPlace $out/dot-profile.d/utils.sh \
      --replace-fail '/usr/bin/nvim' 'command nvim'

    # Every launcher indexes applications from this. /usr/share is empty here,
    # so hardcoding it leaves them all blank.
    substituteInPlace $out/dot-config/hypr/modules/programs.lua \
      --replace-fail '/usr/local/share:/usr/share"' \
        '" .. (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share")'

    # SDDM starts Hyprland without uwsm, so graphical-session.target is never
    # reached and the user units for these never fire.
    substituteInPlace $out/dot-config/hypr/modules/autostart.lua \
      --replace-fail '/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1' \
        '${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1' \
      --replace-fail '/usr/lib/geoclue-2.0/demos/agent' \
        '${pkgs.geoclue2-with-demo-agent}/libexec/geoclue-2.0/demos/agent'

    # git reports a missing credential helper as an auth failure.
    #
    # credentialStore: gpg wants a ~/.password-store, which does not exist here,
    # and GCM dies rather than prompting. secretservice is gnome-keyring, which
    # is already running — and it is what brings back the GUI prompt.
    substituteInPlace $out/dot-gitconfig \
      --replace-fail '/usr/bin/gh' '${pkgs.gh}/bin/gh' \
      --replace-fail 'credentialStore = gpg' 'credentialStore = secretservice'

    # shell_scripts/* are #!/bin/bash, which does not exist here. Hyprland
    # reports nothing for a failed exec bind, so Super+S just looks inert.
    patchShebangs $out

    # Per-machine and gitignored upstream, but hyprland.lua requires it.
    cp ${../hosts + "/${hostName}/monitors.lua"} \
      $out/dot-config/hypr/modules/monitors.lua
  '';

  # Read rather than restated, so the two cannot drift.
  ignore =
    lib.filter (l: l != "" && !lib.hasPrefix "#" l) (
      lib.splitString "\n" (builtins.readFile "${src}/.stow-local-ignore")
    )
    ++ [
      # stow has these built in, or they are plainly not meant for $HOME.
      ".git"
      ".gitattributes"
      ".gitignore"
      ".remember"
      ".stow-local-ignore"
    ];

  # Descended into rather than linked whole: something else owns a path inside
  # them, or the directory has to stay writable.
  expand = [
    "dot-claude"
    "dot-claude/hooks"
    "dot-config"
    "dot-config/caelestia"
    "dot-config/vesktop"
    "dot-config/vesktop/themes"
    "dot-hermes"
    "dot-local"
    "dot-local/share"
    "dot-local/share/icons"
  ];

  # Owned elsewhere: `df`, programs.ydotool and stylix respectively.
  elsewhere = [
    "dot-config/hypr"
    "dot-config/systemd"
    "dot-local/share/icons/Hutao-Cursor"
  ];

  # Per segment, so a "dot-" inside a filename is left alone.
  target =
    p:
    lib.concatMapStringsSep "/" (
      s: if lib.hasPrefix "dot-" s then "." + lib.removePrefix "dot-" s else s
    ) (lib.splitString "/" p);

  walk =
    prefix:
    lib.concatMapAttrs (
      name: type:
      let
        p = if prefix == "" then name else "${prefix}/${name}";
      in
      if builtins.elem name ignore || builtins.elem p ignore || builtins.elem p elsewhere then
        { }
      else if type == "directory" && builtins.elem p expand then
        walk p
      else
        {
          ${target p} = {
            source = "${df}/${p}";
          };
        }
    ) (builtins.readDir "${src}/${prefix}");

  # Linked entry by entry, not as one directory, so ~/.config/nvim stays a real
  # directory lazy.nvim can write lazy-lock.json into. Link it whole and that
  # write fails, which aborts init.lua on every first boot.
  #
  # In-tree since the nvim-config input was dropped, so a config change is one
  # commit here rather than a push there plus `nix flake update nvim-config`.
  nvimSrc = ../nvim;

  nvimConfig = pkgs.runCommandLocal "nvim-config-nixos" { } ''
    cp -r ${nvimSrc} $out
    chmod -R u+w $out
    cp ${./nvim-nixos.lua} $out/lua/plugins/nixos.lua
  '';

  # Written by lazy.nvim; seeded once, then left alone.
  nvimState = [
    "lazy-lock.json"
    "lazyvim.json"
  ];

  # .zshrc's plugins= list, minus the ones oh-my-zsh already ships.
  zshPlugins = [
    {
      name = "zsh-autosuggestions";
      src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
    }
    {
      name = "zsh-syntax-highlighting";
      src = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
    }
    {
      name = "zsh-vi-mode";
      src = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
    }
  ];

  # Assembled rather than symlinked, so the custom plugins are inside $ZSH.
  ohMyZsh = pkgs.runCommandLocal "oh-my-zsh-hutao" { } ''
    cp -r ${pkgs.oh-my-zsh}/share/oh-my-zsh $out
    chmod -R u+w $out
    ${lib.concatMapStringsSep "\n" (
      { name, src }:
      ''
        # Whole tree: these resolve siblings off ''${0:h}, so a lone symlink
        # lands them where the rest of the plugin is not.
        cp -rL ${src} "$out/custom/plugins/${name}"
        chmod -R u+w "$out/custom/plugins/${name}"

        # oh-my-zsh wants <name>.plugin.zsh; nixpkgs ships some as <name>.zsh.
        if [ ! -e "$out/custom/plugins/${name}/${name}.plugin.zsh" ]; then
          echo 'source "''${0:A:h}/${name}.zsh"' \
            > "$out/custom/plugins/${name}/${name}.plugin.zsh"
        fi
      ''
    ) zshPlugins}
  '';
in
{
  imports = [
    inputs.caelestia-shell.homeManagerModules.default
    inputs.hermes-agent.homeManagerModules.default
  ];

  home.stateVersion = "26.05";

  # We own ~/.config wholesale, so stylix's per-app targets would be a second
  # writer for the same files.
  stylix.autoEnable = false;
  stylix.targets.gtk.enable = true;

  home.file = walk "" // {
    # dot-profile and several scripts hardcode $HOME/dotfiles paths.
    "dotfiles".source = df;

    ".oh-my-zsh".source = ohMyZsh;

    # Sourced unguarded by .zshrc and dot-profile, so it only has to exist —
    # atuin itself comes from the system closure.
    ".atuin/bin/env".text = "";
  };

  # nvimState is dropped here and seeded by an activation script below.
  xdg.configFile =
    lib.mapAttrs' (name: _: lib.nameValuePair "nvim/${name}" { source = "${nvimConfig}/${name}"; }) (
      lib.removeAttrs (builtins.readDir nvimSrc) nvimState
    )
    // {
      # Patched and given its monitors.lua by `df`.
      "hypr".source = "${df}/dot-config/hypr";

      # A store symlink, so ccstatusline's own TUI cannot save over it — this
      # file is the source of truth and `nixos-rebuild` restores it. Edit
      # home/ccstatusline.json and rebuild instead of using the picker.
      #
      # ~/.claude/settings.json runs it as `npx -y ccstatusline@latest`; there
      # is no nixpkgs derivation to pin, so the schema is whatever npm serves.
      "ccstatusline/settings.json".source = ./ccstatusline.json;

      # What qt6ct reads for the icon theme; hyprqt6engine.conf is the Arch
      # half of the same setting.
      "qt6ct/qt6ct.conf".text = ''
        [Appearance]
        icon_theme=Papirus-Dark
      '';

      # Lives at the dotfiles repo root, which stow does not link.
      "caelestia/schemes/hu-tao/default/dark.txt".source = ../schemes/hu-tao-dark.txt;

      # Sourced by caelestia's hyprland integration, which creates them itself
      # — but not before Hyprland reads its config.
      "caelestia/hypr-user.conf".text = "";
      "caelestia/hypr-vars.conf".text = "";
    };

  programs.caelestia = {
    enable = true;
    cli.enable = true;
    # autostart.lua already execs it; true here double-starts.
    systemd.enable = false;
    # shell.json is gitignored upstream, so it is vendored here.
    extraConfig = builtins.readFile ./caelestia-shell.json;
  };

  # home-manager splits an installation from a daemon, so hermes takes two
  # option trees: `programs.` puts the CLI on PATH and exports HERMES_HOME,
  # `services.` owns ~/.hermes. gateway.enable is left at its default false —
  # nothing runs in the background, this is a command, not a service.
  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    # Renders ~/.hermes/config.yaml, which until now was a by-hand file that
    # dotfiles gitignored — so this is the first time it is reproducible.
    enable = true;

    # openrouter, because OPENROUTER_API_KEY is what the secret below holds —
    # one key, so one provider. The model id is the one
    # dot-hermes/config.example.yaml already routes through openrouter.
    settings.model = {
      default = "anthropic/claude-opus-4.8";
      provider = "openrouter";
    };

    # A runtime path and a `str`, never a Nix path literal: a path literal
    # would copy the plaintext key into /nix/store, which every user can
    # read. modules/sops.nix gives this secret owner = "hutao", because the
    # activation that reads it is home-manager's and runs unprivileged.
    #
    # Guarded, not unconditional: hutao-vm imports no sops module, and
    # hutao-vm is exactly what CI evaluates.
    environmentFiles = lib.optional (osConfig ? sops) osConfig.sops.secrets."hermes/env".path;
  };

  # caelestia reads ~/.face in dashboard/dash/User.qml and lock/ProfilePic.qml,
  # and its face picker copies into it — so seeded, not linked.
  home.activation.face = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${config.home.homeDirectory}/.face" ]; then
      run cp -L ${df}/dot-config/fastfetch/icons/HuTaoSmall.png \
        "${config.home.homeDirectory}/.face"
      run chmod u+w "${config.home.homeDirectory}/.face"
    fi
  '';

  # lazy.nvim rewrites these, so they cannot be store symlinks. Seeded from the
  # pinned copies, then never touched.
  home.activation.nvimState = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n" (f: ''
      if [ ! -e "${config.xdg.configHome}/nvim/${f}" ]; then
        run mkdir -p "${config.xdg.configHome}/nvim"
        run install -m644 ${nvimConfig}/${f} "${config.xdg.configHome}/nvim/${f}"
      fi
    '') nvimState
  );

  # wallpaperDir is personal data outside the dotfiles repo, so a fresh machine
  # has nothing to show. Seeded from the tracked backgrounds, never overwritten.
  home.activation.wallpapers =
    let
      dir = "${config.home.homeDirectory}/Pictures/Wallpapers";
      state = "${config.xdg.stateHome}/caelestia/wallpaper";
      # `caelestia wallpaper` rewrites both, so they are seeded, not linked.
      current = "${dir}/Hu_Tao_00056_1.png";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${dir}" ]; then
        run mkdir -p "${dir}"
        run cp -L ${df}/dot-config/hypr/backgrounds/* "${dir}"/
        run chmod u+w "${dir}"/*
      fi

      if [ ! -e "${state}/path.txt" ]; then
        run mkdir -p "${state}"
        run ln -sfn "${current}" "${state}/current"
        printf '%s\n' "${current}" > "${state}/path.txt"
      fi
    '';

  # The active scheme is state, rewritten by `caelestia scheme set` — seeded,
  # not linked, so switching still works.
  home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state="${config.xdg.stateHome}/caelestia"
    if [ ! -e "$state/scheme.json" ]; then
      run mkdir -p "$state"
      run install -m600 ${./caelestia-scheme.json} "$state/scheme.json"
    fi
  '';
}
