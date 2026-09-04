# `stow --dotfiles` as a derivation, so ~/.config is read-only. To iterate
# without rebuilding, swap `src` for
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
  # A plain path, so the readDir walk needs no import-from-derivation.
  src = ../dotfiles;

  inherit (osConfig.networking) hostName;

  # --replace-fail: break the build when a patch lands upstream.
  df = pkgs.runCommandLocal "hutao-dotfiles-${hostName}" { } ''
    cp -r ${src} $out
    chmod -R u+w $out

    # `command`, not a path, so the wrapper still shadows itself.
    substituteInPlace $out/dot-profile.d/utils.sh \
      --replace-fail '/usr/bin/nvim' 'command nvim'

    # /usr/share is empty here, so every launcher's app list comes out blank.
    substituteInPlace $out/dot-config/hypr/modules/programs.lua \
      --replace-fail '/usr/local/share:/usr/share"' \
        '" .. (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share")'

    # SDDM starts Hyprland without uwsm, so graphical-session.target never
    # fires and the user units for these never start.
    substituteInPlace $out/dot-config/hypr/modules/autostart.lua \
      --replace-fail '/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1' \
        '${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1' \
      --replace-fail '/usr/lib/geoclue-2.0/demos/agent' \
        '${pkgs.geoclue2-with-demo-agent}/libexec/geoclue-2.0/demos/agent'

    # gpg wants a ~/.password-store that does not exist here, and GCM then
    # dies instead of prompting. secretservice is the running gnome-keyring.
    substituteInPlace $out/dot-gitconfig \
      --replace-fail '/usr/bin/gh' '${pkgs.gh}/bin/gh' \
      --replace-fail 'credentialStore = gpg' 'credentialStore = secretservice'

    # #!/bin/bash does not exist here, and a failed exec bind is silent.
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

  # Something else owns a path inside, or it has to stay writable.
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

  # Linked entry by entry so ~/.config/nvim stays a real directory lazy.nvim
  # can write lazy-lock.json into; linked whole, that write aborts init.lua.
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
        # Whole tree: these resolve siblings off ''${0:h}.
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

  # We own ~/.config wholesale; stylix's targets would be a second writer.
  stylix.autoEnable = false;
  stylix.targets.gtk.enable = true;

  home.file = walk "" // {
    # dot-profile and several scripts hardcode $HOME/dotfiles paths.
    "dotfiles".source = df;

    ".oh-my-zsh".source = ohMyZsh;

    # Sourced unguarded by .zshrc, so it only has to exist.
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

      # Immutable on purpose, so the picker cannot save over it. `version`
      # must match the CURRENT_VERSION of whatever npm serves: on a lower one
      # the tool migrates, writes the result back into /nix/store, hits EROFS
      # and renders "invalid config" off its defaults.
      "ccstatusline/settings.json".source = ./ccstatusline.json;

      # What qt6ct reads for the icon theme; hyprqt6engine.conf is the Arch
      # half of the same setting.
      "qt6ct/qt6ct.conf".text = ''
        [Appearance]
        icon_theme=Papirus-Dark
      '';

      # Outside the dot-* trees, so the walk never reaches it.
      "caelestia/schemes/hu-tao/default/dark.txt".source =
        ../dotfiles/caelestia/schemes/hu-tao/default/dark.txt;

      # caelestia creates these itself, but after Hyprland reads its config.
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

  # `programs.` is the CLI, `services.` owns ~/.hermes. gateway.enable stays
  # at its default false: this is a command, not a daemon.
  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    enable = true;

    # The only free openrouter model that calls tools and has the context an
    # agent needs.
    settings.model = {
      default = "minimax/minimax-m3:free";
      provider = "openrouter";
    };

    # A `str`, never a path literal: a literal would copy the plaintext into
    # /nix/store. Guarded because hutao-vm has no sops module, and hutao-vm is
    # what CI evaluates.
    environmentFiles = lib.optional (osConfig ? sops) osConfig.sops.secrets."hermes/env".path;
  };

  # caelestia's face picker writes to ~/.face, so seed it.
  home.activation.face = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${config.home.homeDirectory}/.face" ]; then
      run cp -L ${df}/dot-config/fastfetch/icons/HuTaoSmall.png \
        "${config.home.homeDirectory}/.face"
      run chmod u+w "${config.home.homeDirectory}/.face"
    fi
  '';

  # lazy.nvim rewrites these, so they cannot be store symlinks.
  home.activation.nvimState = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n" (f: ''
      if [ ! -e "${config.xdg.configHome}/nvim/${f}" ]; then
        run mkdir -p "${config.xdg.configHome}/nvim"
        run install -m644 ${nvimConfig}/${f} "${config.xdg.configHome}/nvim/${f}"
      fi
    '') nvimState
  );

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
        run cp -L ${df}/dot-config/hypr/backgrounds/* "${dir}"/
        run chmod u+w "${dir}"/*
      fi

      if [ ! -e "${state}/path.txt" ]; then
        run mkdir -p "${state}"
        run ln -sfn "${current}" "${state}/current"
        printf '%s\n' "${current}" > "${state}/path.txt"
      fi
    '';

  # Rewritten by `caelestia scheme set`, so seeding keeps switching working.
  home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state="${config.xdg.stateHome}/caelestia"
    if [ ! -e "$state/scheme.json" ]; then
      run mkdir -p "$state"
      run install -m600 ${./caelestia-scheme.json} "$state/scheme.json"
    fi
  '';
}
