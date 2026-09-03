# The user layer. Replaces `stow --dotfiles` from the dotfiles repo: the same
# tree, the same dot-foo -> .foo renaming, the same ignore file — but every
# path is a symlink into the store instead of into a working tree.
#
# Consequences, both deliberate:
#   - ~/.config is read-only. Apps that persist settings there (fcitx5) cannot.
#   - `nix flake update dotfiles` is how a dotfiles change lands. To iterate
#     without pushing, swap `src` for
#       config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles"
{
  inputs,
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:
let
  # readDir this one: it is a plain source path, so walking it costs no
  # import-from-derivation. `df` below is what everything actually links to.
  src = inputs.dotfiles;

  inherit (osConfig.networking) hostName;

  # The tree as it needs to be on NixOS.
  #
  # --replace-fail on purpose: when one of these lands upstream the build
  # breaks instead of silently doing nothing, and the patch gets deleted here.
  df = pkgs.runCommandLocal "hutao-dotfiles-${hostName}" { } ''
    cp -r ${src} $out
    chmod -R u+w $out

    # `command`, not an FHS path, so the wrapper still shadows itself.
    substituteInPlace $out/dot-profile.d/utils.sh \
      --replace-fail '/usr/bin/nvim' 'command nvim'

    # env.lua exports this to the whole session and both wofi and caelestia's
    # launcher index applications from it. /usr/share holds nothing here, so
    # hardcoding it leaves every launcher empty.
    substituteInPlace $out/dot-config/hypr/modules/programs.lua \
      --replace-fail '/usr/local/share:/usr/share"' \
        '" .. (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share")'

    # Both of these also exist as services, but Hyprland here is started by
    # SDDM without uwsm, so nothing reaches graphical-session.target and the
    # user units never fire. Point autostart.lua at the real binaries.
    substituteInPlace $out/dot-config/hypr/modules/autostart.lua \
      --replace-fail '/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1' \
        '${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1' \
      --replace-fail '/usr/lib/geoclue-2.0/demos/agent' \
        '${pkgs.geoclue2-with-demo-agent}/libexec/geoclue-2.0/demos/agent'

    # Every script in dot-config/programs/shell_scripts is #!/bin/bash, and
    # NixOS has no /bin/bash. execve returns ENOENT, Hyprland's exec keybind
    # reports nothing, and Super+S looks like it simply does nothing. Rewrites
    # them to the store's bash; grim/slurp/tesseract were never the problem.
    patchShebangs $out

    # Per-machine and gitignored upstream, but hyprland.lua requires it.
    cp ${../hosts + "/${hostName}/monitors.lua"} \
      $out/dot-config/hypr/modules/monitors.lua
  '';

  # Read the repo's own ignore file rather than restating it, so the two
  # cannot drift. .git and the agent scratch dir are not in it.
  ignore =
    lib.filter (l: l != "" && !lib.hasPrefix "#" l) (
      lib.splitString "\n" (builtins.readFile "${src}/.stow-local-ignore")
    )
    ++ [
      # Not in that file, but stow has them built in or they are plainly not
      # meant for $HOME.
      ".git"
      ".gitattributes"
      ".gitignore"
      ".remember"
      ".stow-local-ignore"
    ];

  # Walked into rather than symlinked whole, because something else owns a
  # path inside them — or, for dot-claude, because Claude Code needs the rest
  # of ~/.claude to stay writable.
  expand = [
    "dot-claude"
    "dot-claude/hooks"
    "dot-config"
    "dot-config/caelestia"
    "dot-hermes"
    "dot-local"
    "dot-local/share"
    "dot-local/share/icons"
  ];

  # Owned below or by another module: the hypr tree comes from `df`,
  # programs.ydotool supersedes the unit, stylix installs the cursor theme.
  elsewhere = [
    "dot-config/hypr"
    "dot-config/systemd"
    "dot-local/share/icons/Hutao-Cursor"
  ];

  # dot-foo/bar -> .foo/bar, per segment so a "dot-" inside a filename is
  # left alone.
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

  # ~/.config/nvim, with the NixOS-only plugin spec added.
  #
  # Linked entry by entry below rather than as one directory, so ~/.config/nvim
  # is a real directory that lazy.nvim can write its two state files into.
  # Point it whole at the store and `:Lazy update` cannot write lazy-lock.json
  # — and that failure aborts init.lua on any start with plugins to install,
  # which is every first boot.
  nvimSrc = "${inputs.nvim-config}/nvim";

  nvimConfig = pkgs.runCommandLocal "nvim-config-nixos" { } ''
    cp -r ${nvimSrc} $out
    chmod -R u+w $out
    cp ${./nvim-nixos.lua} $out/lua/plugins/nixos.lua
  '';

  # Written by lazy.nvim and :LazyExtras. Seeded from the pinned copy on first
  # activation, then left alone.
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

  # .zshrc sources $ZSH/oh-my-zsh.sh, and exports.sh points $ZSH at
  # ~/.oh-my-zsh. Assembled here so the custom plugins are inside it.
  ohMyZsh = pkgs.runCommandLocal "oh-my-zsh-hutao" { } ''
    cp -r ${pkgs.oh-my-zsh}/share/oh-my-zsh $out
    chmod -R u+w $out
    ${lib.concatMapStringsSep "\n" (
      { name, src }:
      ''
        # The whole tree, not just the entry point: these plugins resolve their
        # own siblings off ''${0:h}, so a lone symlink lands them in a directory
        # where the rest of the plugin is not.
        cp -rL ${src} "$out/custom/plugins/${name}"
        chmod -R u+w "$out/custom/plugins/${name}"

        # oh-my-zsh sources <name>.plugin.zsh; nixpkgs ships some as <name>.zsh.
        if [ ! -e "$out/custom/plugins/${name}/${name}.plugin.zsh" ]; then
          echo 'source "''${0:A:h}/${name}.zsh"' \
            > "$out/custom/plugins/${name}/${name}.plugin.zsh"
        fi
      ''
    ) zshPlugins}
  '';
in
{
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  home.stateVersion = "26.05";

  # We own ~/.config wholesale, so stylix's per-app targets would be a second
  # writer for the same files. Keep only the ones nothing else touches.
  stylix.autoEnable = false;
  stylix.targets.gtk.enable = true;

  home.file = walk "" // {
    # dot-profile hardcodes $HOME/dotfiles/dot-profile.d, and autostart.lua
    # and several scripts reference $HOME/dotfiles paths.
    "dotfiles".source = df;

    ".oh-my-zsh".source = ohMyZsh;

    # .zshrc and dot-profile both `. "$HOME/.atuin/bin/env"` unguarded. atuin
    # itself comes from the system closure, so this only has to exist.
    ".atuin/bin/env".text = "";
  };

  xdg.configFile =
    lib.mapAttrs' (name: _: lib.nameValuePair "nvim/${name}" { source = "${nvimConfig}/${name}"; }) (
      lib.removeAttrs (builtins.readDir nvimSrc) nvimState
    )
    // {
      # Patched and given its monitors.lua by `df`.
      "hypr".source = "${df}/dot-config/hypr";

      # Plugins install to ~/.local/share/nvim. To move the pin:
      #   nix flake update nvim-config && sudo nixos-rebuild switch --flake .#<host>

      # Lives at the dotfiles repo root, which stow does not link.
      "caelestia/schemes/hu-tao/default/dark.txt".source = ../schemes/hu-tao-dark.txt;

      # Sourced by caelestia's hyprland integration. Empty upstream too; the
      # shell creates them on its own, but not before Hyprland reads its config.
      "caelestia/hypr-user.conf".text = "";
      "caelestia/hypr-vars.conf".text = "";
    };

  programs.caelestia = {
    enable = true;
    cli.enable = true;
    # Started from Hyprland by autostart.lua. Flipping this to true means
    # removing that exec, or it double-starts.
    systemd.enable = false;
    # shell.json is gitignored upstream, so it is vendored here.
    extraConfig = builtins.readFile ./caelestia-shell.json;
  };

  # lazy.nvim rewrites these, so they cannot be store symlinks. Seeded from
  # the pinned copies so a fresh machine still gets the pinned plugin
  # versions, then never touched again.
  home.activation.nvimState = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n" (f: ''
      if [ ! -e "${config.xdg.configHome}/nvim/${f}" ]; then
        run mkdir -p "${config.xdg.configHome}/nvim"
        run install -m644 ${nvimConfig}/${f} "${config.xdg.configHome}/nvim/${f}"
      fi
    '') nvimState
  );

  # shell.json's paths.wallpaperDir is personal data that lives outside the
  # dotfiles repo, so a fresh machine has nothing to show. Seed the directory
  # from the tracked backgrounds and point caelestia's active-wallpaper state
  # at the one hyprpaper.conf names — but never touch either if it exists.
  home.activation.wallpapers =
    let
      dir = "${config.home.homeDirectory}/Pictures/Wallpapers";
      state = "${config.xdg.stateHome}/caelestia/wallpaper";
      # `caelestia wallpaper` rewrites both of these, so they are seeded, not
      # symlinked into the store.
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

  # The shell reads the *active* scheme from state, not from the scheme
  # directory above, and rewrites it on `caelestia scheme set`. Seeded rather
  # than symlinked so switching schemes still works.
  home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state="${config.xdg.stateHome}/caelestia"
    if [ ! -e "$state/scheme.json" ]; then
      run mkdir -p "$state"
      run install -m600 ${./caelestia-scheme.json} "$state/scheme.json"
    fi
  '';
}
