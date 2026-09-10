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

  folderIcons = pkgs.callPackage ../pkgs/hutao-folder-icons.nix { };

  # Icons for the hand-written ~/.local/share/applications entries.
  app-icons = pkgs.callPackage ../pkgs/app-icons.nix { };

  palette = import ../palette.nix { inherit lib; };
  inherit (palette)
    hex
    argb
    rgba
    ramp
    ;

  # kitty's palette, generated whole rather than patched: the file is nothing
  # but colours, so substituting all 26 would be a worse way to say the same
  # thing. The name stays -- kitty.conf includes it by path, and colors.sh
  # reads `background` back out of it for the tmux status bar.
  kittyColours = pkgs.writeText "mocha.conf" ''
    # vim:ft=kitty
    #
    # Generated from the caelestia scheme; see palette.nix. Was a hand-edited
    # Catppuccin Mocha, which is where the filename comes from.

    # The basic colors
    foreground              ${hex.text}
    background              ${hex.base}
    selection_foreground    ${hex.base}
    selection_background    ${hex.rosewater}

    # Cursor colors
    cursor                  ${hex.rosewater}
    cursor_text_color       ${hex.base}

    # URL underline color when hovering with mouse
    url_color               ${hex.klink}

    # Kitty window border colors
    active_border_color     ${hex.primary}
    inactive_border_color   ${hex.outline}
    bell_border_color       ${hex.tertiary}

    # OS Window titlebar colors
    wayland_titlebar_color system
    macos_titlebar_color system

    # Tab bar colors
    active_tab_foreground   ${hex.onPrimary}
    active_tab_background   ${hex.red}
    inactive_tab_foreground ${hex.peach}
    inactive_tab_background ${hex.onSecondary}
    tab_bar_background      ${hex.onPrimary}

    # Colors for marks (marked text in the terminal)
    mark1_foreground ${hex.surfaceContainerHigh}
    mark1_background ${hex.primaryFixed}
    mark2_foreground ${hex.surfaceContainerHigh}
    mark2_background ${hex.flamingo}
    mark3_foreground ${hex.surfaceContainerHigh}
    mark3_background ${hex.primary}

    # The 16 terminal colors, straight off the scheme's own term0..term15.
    ${lib.concatStringsSep "\n" (
      map (i: "color${toString i} ${hex."term${toString i}"}") (lib.range 0 15)
    )}
  '';

  # The nine-step pink the nvim colourscheme overrides Catppuccin with. Its
  # own 1st, 5th and 9th steps were already scheme colours; the six between
  # them were literals, so the whole ladder is interpolated off those anchors
  # instead (palette.nix's `ramp`) and follows a retune.
  nvimRamp = ramp "flamingo" "mauve" 5 ++ lib.tail (ramp "mauve" "onSecondaryFixedVariant" 5);

  # Colours still written as literals in the dotfiles, by the scheme key each
  # one means. The in-tree literal doubles as the placeholder: every config
  # stays valid when ~/.config is pointed at the raw tree (see the header),
  # and --replace-fail turns an upstream edit into a failed build rather than
  # a colour that quietly stopped following the scheme.
  #
  # Lists, not attrsets, because order matters where one token is a prefix of
  # another (swaylock's rrggbbaa).
  recolour = {
    "dot-config/kitty/kitty.conf" = [
      # Set after the mocha.conf include, so this is the one that wins.
      { "#0087bd" = hex.klink; }
    ];

    "dot-config/waybar/style.css" = [
      { "#ff3333" = hex.primary; }
      { "#ff6666" = hex.primaryFixed; }
      { "#ff1a1a" = hex.red; }
      { "rgba(0, 0, 0, 0.9)" = rgba "scrim" "0.9"; }
    ];

    "dot-config/waybar/config.jsonc" = [
      { "#bf616a" = hex.red; }
      { "#ffead3" = hex.yellow; }
      { "#ecc6d9" = hex.term7; }
      { "#99ffdd" = hex.teal; }
      { "#ffcc66" = hex.peach; }
      { "#ff6699" = hex.primary; }
      { "#f53c3c" = hex.red; }
    ];

    "dot-config/wofi/style.css" = [
      { "rgba(24, 12, 12, 0.8)" = rgba "base" "0.8"; }
      { "rgba(24, 12, 12, 0.1)" = rgba "base" "0.1"; }
      { "rgba(255, 128, 128, 0.5)" = rgba "red" "0.5"; }
      { "rgba(255, 128, 128, 0.1)" = rgba "red" "0.1"; }
      { "#a55" = hex.mauve; }
      { "#eee" = hex.text; }
    ];

    "dot-config/wlogout/style.css" = [
      { "#ff4b4b" = hex.red; }
      { "rgba(0, 0, 0, 0.85)" = rgba "scrim" "0.85"; }
      { "rgba(255, 0, 0, 0.5)" = rgba "red" "0.5"; }
      { "rgba(255, 0, 0, 0.2)" = rgba "red" "0.2"; }
    ];

    # Rose Pine, every value of it, until now. Bare hex like the file's own,
    # and the rrggbbaa tokens ahead of the rrggbb they start with.
    "dot-config/swaylock/config" = [
      { "1f1d2e80" = argb "surface0" "80"; }
      { "00000000" = argb "scrim" "00"; }
      { "1f1d2e" = palette.colours.surface0; }
      { "191724" = palette.colours.base; }
      { "eb6f92" = palette.colours.primary; }
      { "e0def4" = palette.colours.text; }
      { "31748f" = palette.colours.red; }
      { "9ccfd8" = palette.colours.green; }
    ];

    "dot-config/mako/config" = [
      { "#330101" = hex.surfaceVariant; }
      { "#551111" = hex.overlay0; }
      { "#d08770" = hex.maroon; }
      { "#bf616a" = hex.red; }
    ];

    "dot-config/hypr/modules/look_and_feel.lua" = [
      { "rgba(ff3333ee)" = "rgba(${argb "primary" "ee"})"; }
      { "rgba(ff0099ee)" = "rgba(${argb "term5" "ee"})"; }
      { "rgba(595959aa)" = "rgba(${argb "outline" "aa"})"; }
      { "rgba(1a1a1aee)" = "rgba(${argb "crust" "ee"})"; }
    ];

    "dot-config/lazygit/config.yml" = [
      { "#ff5077" = hex.primary; }
      { "#da5876" = hex.term5; }
      { "#ffaa88" = hex.onSecondaryContainer; }
      { "#541f27" = hex.onSecondaryFixedVariant; }
      { "#ffb3c3" = hex.primaryFixedDim; }
    ];

    # Bare hex, no leading '#'.
    "dot-config/MangoHud/MangoHud.conf" = [
      { "c8c5d1" = palette.colours.subtext1; }
      { "190707" = palette.colours.base; }
      { "d94f6e" = palette.colours.term5; }
      { "eb6c6c" = palette.colours.primary; }
      { "ab6670" = palette.colours.mauve; }
      { "d3a891" = palette.colours.flamingo; }
    ];

    "dot-config/starship.toml" = [
      { "#d29db0" = hex.primaryFixedDim; }
      { "#090c0b" = hex.crust; }
      { "#f07185" = hex.primary; }
      { "#e4e3e5" = hex.text; }
      { "#603745" = hex.secondaryContainer; }
      { "#362124" = hex.surfaceContainerHighest; }
      { "#301e1d" = hex.surfaceContainerHigh; }
      { "#caa0a8" = hex.kpositive; }
    ];

    "dot-config/vesktop/themes/BasicBackground.theme.css" = [
      { "rgba(0, 0, 0, 0.85)" = rgba "scrim" "0.85"; }
      { "rgba(0, 0, 0, 0)" = rgba "scrim" "0"; }
    ];

    # The five base hues were already scheme colours. Their -2..-5 steps were
    # baked rgb() percentages -- caelestia's generator darkening each hue by
    # 5% of its HSL lightness per step -- so they become that same step
    # expressed against the hue above them, and follow it.
    "dot-config/vesktop/themes/caelestia.theme.css" = [
      { "#130a0c" = hex.base; }
      { "#3a0000" = hex.onPrimary; }
      { "#8a5560" = hex.outline; }
      { "#362328" = hex.surface2; }
      { "#2a191e" = hex.surfaceContainerHigh; }
      { "#201317" = hex.surfaceContainer; }
      { "#ff6b69" = hex.red; }
      { "#ff9b8a" = hex.green; }
      { "#EB6C6C" = hex.primary; }
      { "#ffe9c7" = hex.yellow; }
      { "#ab6670" = hex.mauve; }
      { "#e5e1e7" = hex.text; }
      { "rgb(90.8235294118%, 89.4117647059%, 91.5294117647%)" = "var(--text-3)"; }
      { "rgb(90.3137254902%, 88.8235294118%, 91.0588235294%)" = "var(--text-3)"; }
      { "rgba(229, 225, 231, 0.08)" = rgba "text" "0.08"; }
      { "rgba(229, 225, 231, 0.1)" = rgba "text" "0.1"; }
      { "rgba(229, 225, 231, 0.2)" = rgba "text" "0.2"; }
      { "rgba(138, 85, 96, 0.2)" = rgba "outline" "0.2"; }
      { "rgba(138, 85, 96, 0)" = rgba "outline" "0"; }
      { "rgb(100%, 34.9960784314%, 34.1176470588%)" = darker "--red-1" 1; }
      { "rgb(100%, 28.031372549%, 27.0588235294%)" = darker "--red-1" 2; }
      { "rgb(100%, 21.0666666667%, 20%)" = darker "--red-1" 3; }
      { "rgb(100%, 14.1019607843%, 12.9411764706%)" = darker "--red-1" 4; }
      { "rgb(100%, 54.1980894922%, 46.4117647059%)" = darker "--green-1" 1; }
      { "rgb(100%, 47.6118652589%, 38.7058823529%)" = darker "--green-1" 2; }
      { "rgb(100%, 41.0256410256%, 31%)" = darker "--green-1" 3; }
      { "rgb(100%, 34.4394167924%, 23.2941176471%)" = darker "--green-1" 4; }
      { "rgb(91.3514148174%, 36.4328989081%, 36.4328989081%)" = darker "--blue-1" 1; }
      { "rgb(90.5459668897%, 30.5128566397%, 30.5128566397%)" = darker "--blue-1" 2; }
      { "rgb(89.7405189621%, 24.5928143713%, 24.5928143713%)" = darker "--blue-1" 3; }
      { "rgb(88.9350710344%, 18.6727721029%, 18.6727721029%)" = darker "--blue-1" 4; }
      { "rgb(100%, 87.8753501401%, 69.137254902%)" = darker "--yellow-1" 1; }
      { "rgb(100%, 84.3781512605%, 60.2352941176%)" = darker "--yellow-1" 2; }
      { "rgb(100%, 80.880952381%, 51.3333333333%)" = darker "--yellow-1" 3; }
      { "rgb(100%, 77.3837535014%, 42.431372549%)" = darker "--yellow-1" 4; }
      { "rgb(65.1615785555%, 36.5443037975%, 40.6917349218%)" = darker "--purple-1" 1; }
      { "rgb(62.2025316456%, 34.1504095309%, 38.2159344751%)" = darker "--purple-1" 2; }
      { "rgb(58.746835443%, 32.253164557%, 36.0928270042%)" = darker "--purple-1" 3; }
      { "rgb(55.2911392405%, 30.355919583%, 33.9697195334%)" = darker "--purple-1" 4; }
    ];
  };

  # 5% of the HSL lightness per step, off the hue's own var, so the ladder is
  # the browser's arithmetic on one palette colour instead of twenty baked
  # percentages. Relative colour syntax; Vesktop's Electron is well past it.
  darker =
    var: n:
    let
      factor = lib.foldl' (acc: _: acc * 0.95) 1.0 (lib.range 1 n);
    in
    "hsl(from var(${var}) h s calc(l * ${toString factor}))";

  # stow put the tree at ~/dotfiles and these paths followed it there. It is a
  # derivation now, linked into the same ~/.config, ~/.local and ~/.profile.d
  # the walk builds, so they point at that instead: one home.file link fewer
  # to keep alive, and a half-finished activation can no longer take every
  # keybind, the wallpaper and the shell env out together. The prefix form is
  # left as it was -- whatever expanded `~` or `$HOME` before still does.
  repath = {
    "dot-bashrc" = [ { "$HOME/dotfiles/dot-profile.d/" = "$HOME/.profile.d/"; } ];
    "dot-profile" = [ { "$HOME/dotfiles/dot-profile.d/" = "$HOME/.profile.d/"; } ];

    "dot-config/fastfetch/config.jsonc" = [
      { "~/dotfiles/dot-config/fastfetch/" = "~/.config/fastfetch/"; }
    ];

    "dot-config/hypr/hyprlock.conf" = [
      { "$HOME/dotfiles/dot-config/hypr/" = "$HOME/.config/hypr/"; }
    ];

    "dot-config/hypr/hyprpaper.conf" = [
      { "~/dotfiles/dot-config/hypr/" = "~/.config/hypr/"; }
    ];

    # One prefix, seven binds -- substituteInPlace replaces every occurrence.
    "dot-config/hypr/modules/keybindings.lua" = [
      { "~/dotfiles/dot-config/programs/" = "~/.config/programs/"; }
    ];

    "dot-config/hypr/modules/autostart.lua" = [
      { "~/dotfiles/dot-config/programs/" = "~/.config/programs/"; }
    ];

    "dot-config/opencode/opencode.json" = [
      { "~/dotfiles/dot-opencode/" = "~/.opencode/"; }
    ];

    # It writes into ICON_DIR, which was a store path via ~/dotfiles and is a
    # store path via ~/.local -- read-only either way, so this changes the
    # route and not the outcome.
    "dot-config/programs/shell_scripts/add-icon.sh" = [
      { "$HOME/dotfiles/dot-local/" = "$HOME/.local/"; }
    ];
  };

  # One substituteInPlace per file, --replace-fail per pair.
  substPhase =
    files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (path: pairs: ''
        substituteInPlace $out/${path} \
          ${lib.concatMapStringsSep " \\\n          " (
            pair:
            let
              from = lib.head (lib.attrNames pair);
            in
            "--replace-fail '${from}' '${pair.${from}}'"
          ) pairs}
      '') files
    );

  # What `caelestia scheme set` would write, built from the scheme file it
  # would have read, so the seed below is never a second copy of the colours.
  caelestiaScheme = (pkgs.formats.json { }).generate "caelestia-scheme.json" palette.schemeJson;

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

    # TPM would clone these into ~/.tmux at runtime; nixpkgs already ships them.
    substituteInPlace $out/dot-tmux.conf \
      --replace-fail '/usr/share/tmux-plugins/resurrect' \
        '${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect' \
      --replace-fail '/usr/share/tmux-plugins/continuum' \
        '${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum'

    # #!/bin/bash does not exist here, and a failed exec bind is silent.
    patchShebangs $out

    # Per-machine and gitignored upstream, but hyprland.lua requires it.
    cp ${../hosts + "/${hostName}/monitors.lua"} \
      $out/dot-config/hypr/modules/monitors.lua

    # ── Paths ────────────────────────────────────────────────────────────
    ${substPhase repath}

    # ── Colours ──────────────────────────────────────────────────────────
    cp ${kittyColours} $out/dot-config/mocha/mocha.conf

    ${substPhase recolour}
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
    # cargo writes registry/, git/ and .package-cache INSIDE ~/.cargo. Linked
    # whole, the directory is a store symlink and every one of those writes
    # fails read-only — no cargo build can run, and lspconfig's rust_analyzer
    # reads ~/.cargo/registry/src on every buffer. dot-cargo holds only
    # config.toml, so entry-by-entry costs one link and keeps the dir real.
    "dot-cargo"
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
    "dot-local/share/icons/${osConfig.stylix.cursor.name}"
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

    # Two files hold every colour the config picks: utils/colors.lua for the
    # highlights it sets itself, catppuccin.lua for the ramp it overrides the
    # colourscheme's own greys with.
    substituteInPlace $out/lua/utils/colors.lua \
      --replace-fail '#110000' '${hex.base}' \
      --replace-fail '#ff5077' '${hex.primary}' \
      --replace-fail '#ff9999' '${hex.secondary}' \
      --replace-fail '#ffaa88' '${hex.onSecondaryContainer}' \
      --replace-fail '#ff003e' '${hex.red}' \
      --replace-fail '#da5876' '${hex.term5}' \
      --replace-fail '#ffb3c3' '${hex.primaryFixedDim}'

    substituteInPlace $out/lua/plugins/catppuccin.lua \
      ${lib.concatStringsSep " \\\n      " (
        lib.zipListsWith (from: to: "--replace-fail '${from}' '#${to}'") [
          "#f7c0c8"
          "#e6aab3"
          "#d4939d"
          "#c17c87"
          "#ab6670"
          "#965159"
          "#7f3e44"
          "#6a2f36"
          "#541f27"
        ] nvimRamp
      )}
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

    # The editor toolchain, split out only because it is long. A
    # home-manager module, not a NixOS one -- see its header.
    ../modules/neovim.nix
  ];

  home.stateVersion = "26.05";

  # ── Packages ─────────────────────────────────────────────────────────────
  # What the keybinds, scripts and dotfiles actually call. All of it
  # userspace, so a user profile rather than environment.systemPackages;
  # modules/desktop.nix keeps only what the SDDM greeter or root needs.
  #
  # Absent on purpose, not missing: gamemode, ydotool and bluez (mpris-proxy)
  # come from programs.gamemode.enable, programs.ydotool.enable and
  # hardware.bluetooth.enable, each of which installs its own package.
  home.packages = with pkgs; [
    # terminal / file manager  (the editor toolchain is modules/neovim.nix)
    kitty
    nautilus
    floorp-bin

    # launcher + session  (keybindings.lua: SUPER+Space, SUPER+M)
    wofi
    wlogout
    app2unit # how caelestia launches everything it launches

    # hypr tooling
    hyprpaper
    hyprshot
    hyprpicker

    # vibe coding
    claude-code
    opencode

    # clipboard  (SUPER+CTRL+V, autostart cliphist watchers)
    wl-clipboard
    cliphist

    # screenshots + OCR  (screenshot-*.sh, tesseract-screenshot.sh)
    grim
    slurp
    swappy
    tesseract

    # notifications, 12 call sites across the scripts
    libnotify

    # media + brightness keys
    playerctl
    brightnessctl
    pavucontrol

    # autostart.lua
    gnome-keyring
    polkit_gnome
    gammastep
    espanso-wayland # the plain espanso build cannot see a Wayland session
    trash-cli # trash-empty
    glib # gsettings

    # what .zshrc and dot-profile.d/*.sh call
    atuin
    libsecret # secret-tool, in environment.sh
    python3 # urlencode/urldecode in aliases.sh, and programs/py_scripts
    mpv # caelestia general.apps.playback
    libqalculate # qalc, the launcher's calculator action
    xdg-utils # xdg-open, in the shell_scripts
    xcursorgen # add-icon.sh
    ffmpeg # compress_video.py
    nano

    # shell / cli  (from the Arch list). modules/system.nix keeps root's own
    # vim and curl, and nothing else -- these are the interactive set.
    btop
    fzf
    ripgrep
    lsd
    zoxide
    starship
    lazygit
    fastfetch
    tmux
    stow
    jq
    wget
    zip
    unzip
    p7zip # 7z, 7za, 7zr
    git
    git-lfs

    # dev
    clang
    nodejs
    # Rust's default linker driver is `cc`, which is clang-wrapper here, and it
    # ships only ld.bfd/ld.gold -- `-fuse-ld=lld` fails with "invalid linker
    # name". mold is the fastest of the three and is what dot-cargo/config.toml
    # asks for via link-arg. Verified: clang -fuse-ld=mold links, lld does not.
    mold

    # gaming
    mangohud

    # GCM works here only because `df` rewrites credentialStore to
    # secretservice; gpg wants a ~/.password-store that does not exist.
    gh
    git-credential-manager

    # What programs.gnupg.agent already points its pinentryPackage at; here so
    # a signing prompt outside the agent still finds it.
    pinentry-gnome3

    # hyprqt6engine.conf names the theme; qt6ct is what reads it. The per-user
    # profile is on QT_PLUGIN_PATH, so the plugin loads from here.
    papirus-icon-theme
    qt6Packages.qt6ct

    # Hutao-Cursor inherits from Adwaita, so any shape it lacks needs this.
    adwaita-icon-theme

    # caelestia's launcher favourites reference both.
    vesktop

    viber

    # The background service only: `stremio` itself was removed from nixpkgs
    # for depending on the outdated qt5 webengine, and the web app is what
    # this is for.
    stremio-service

    ente-auth

    # misc from the Arch list
    xauth
    xhost

    # let-bound above; a `let` binding shadows `with pkgs`.
    app-icons
  ];

  # We own ~/.config wholesale; stylix's targets would be a second writer.
  stylix.autoEnable = false;
  stylix.targets.gtk.enable = true;

  # Nothing set an icon theme before this, which left every GTK app on
  # Adwaita's default while qt6ct was pointed at Papirus-Dark. Hutao-Folders
  # inherits Papirus-Dark, so this is also what settles that split -- the
  # folders come from the pack, everything else from the set Qt was already
  # using. home-manager writes it to both gtk-3.0 and gtk-4.0 settings.ini and
  # mirrors it into dconf, which is the one nautilus reads.
  gtk.iconTheme = {
    package = folderIcons;
    name = folderIcons.themeName;
  };

  # libadwaita decides light or dark from this key and nothing else. stylix's
  # gtk.css repaints every named colour dark, but a GTK4 app still comes up on
  # libadwaita's light palette until the key says otherwise -- which is why
  # nautilus was white with hu-tao accents. The only stylix target that sets
  # it is `gnome`, gated on GDM or the GNOME desktop being enabled, so on
  # Hyprland it never runs. Read off polarity rather than hardcoded, so
  # flipping stylix flips this too.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if osConfig.stylix.polarity == "light" then "prefer-light" else "prefer-dark";

  # The GTK3 half of the same switch, for apps that read the setting rather
  # than the theme's colours (Firefox picks its own light/dark off it).
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = osConfig.stylix.polarity != "light";
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = osConfig.stylix.polarity != "light";

  home.file = walk "" // {
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
      # half of the same setting. Hutao-Folders inherits Papirus-Dark, so a Qt
      # app sees what it saw before plus the folders.
      "qt6ct/qt6ct.conf".text = ''
        [Appearance]
        icon_theme=${folderIcons.themeName}
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
  # vim.loader keys its bytecode cache on path + mtime + size, and catppuccin
  # compiles the whole theme into one .luac of its own. Every lua file here is
  # a store symlink with mtime pinned to 1970 and the recolour swaps hex for
  # hex of the same byte length, so all three parts of that key hold still
  # across a palette retune: nvim keeps serving bytecode compiled before the
  # scheme changed, which is why the greys stayed catppuccin's own. Dropped
  # wholesale rather than diffed -- it is derived data, nvim rebuilds it on
  # the next start, and the alternative is teaching two caches about the Nix
  # store.
  home.activation.nvimCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -rf ${config.xdg.cacheHome}/nvim/luac ${config.xdg.cacheHome}/nvim/catppuccin
  '';

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

  # Hyprland reads its config once, at launch, and watches that file for
  # changes. A rebuild never changes a file: it points ~/.config/hypr at a new
  # store path, and the old immutable one the watcher holds is never touched.
  # So autoreload cannot fire, and an edit sits in the store doing nothing
  # until the next login -- which presents as "I changed the config, rebuilt,
  # and nothing happened".
  #
  # After linkGeneration, not writeBoundary: writeBoundary entries run before
  # the new symlinks are in place, so a reload there would re-read the old
  # config. `hyprctl -i` takes a signature, and finds its own runtime dir when
  # XDG_RUNTIME_DIR is unset, which it is in the activation service.
  #
  # Unconditional, rather than diffing generations first: reloading a config
  # that did not change costs nothing, and the dotfiles are one derivation, so
  # a diff could not tell a hypr edit from a waybar one anyway.
  # The shell is a Qt process that caches every icon lookup it makes, and it
  # resolves them out of whichever profile held app-icons when it started.
  # Moving that package between environment.systemPackages and home.packages
  # therefore breaks the launcher's icons in a live session and nothing short
  # of a restart fixes it -- the files are correct, the process is not. There
  # is no reload in the shell's IPC (`caelestia shell -s`), so it has to be
  # killed and started again.
  #
  # The switch itself runs with no session attached, so `-d` on its own would
  # find no Wayland display: the env comes off the process being replaced, and
  # the kill only happens once that has been read. Best-effort throughout,
  # like the hyprland reload below -- no shell running, nothing to do, and a
  # failure here must not fail the switch.
  home.activation.caelestiaReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    pid=$(${pkgs.procps}/bin/pgrep -u "$UID" -x quickshell 2>/dev/null | head -1 || true)
    if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
      wl=$(tr '\0' '\n' < "/proc/$pid/environ" | grep -m1 '^WAYLAND_DISPLAY=' || true)
      sig=$(tr '\0' '\n' < "/proc/$pid/environ" | grep -m1 '^HYPRLAND_INSTANCE_SIGNATURE=' || true)
      if [ -n "$wl" ]; then
        run ${config.programs.caelestia.package}/bin/caelestia shell -k || true
        run env "$wl" "$sig" \
          ${config.programs.caelestia.package}/bin/caelestia shell -d || true
      fi
    fi
  '';

  home.activation.hyprlandReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for sock in "''${XDG_RUNTIME_DIR:-/run/user/$UID}"/hypr/*/.socket.sock; do
      # No instance running (a first login, or a rebuild over ssh).
      [ -S "$sock" ] || continue

      sig=''${sock%/.socket.sock}
      # A reload is best-effort: a stale socket must not fail the switch.
      run ${osConfig.programs.hyprland.package}/bin/hyprctl \
        -i "''${sig##*/}" reload || true
    done
  '';

  # Rewritten by `caelestia scheme set`, so seeding keeps switching working.
  home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state="${config.xdg.stateHome}/caelestia"
    if [ ! -e "$state/scheme.json" ]; then
      run mkdir -p "$state"
      run install -m600 ${caelestiaScheme} "$state/scheme.json"
    fi
  '';
}
