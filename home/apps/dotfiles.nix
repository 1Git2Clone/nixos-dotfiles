# `stow --dotfiles` as a derivation, so ~/.config is read-only. To iterate
# without rebuilding, swap `src` for
#   config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles"
#
# Published as the `dotfiles` module argument, so the few apps that read a
# path back out of the tree can take it without rebuilding it.
{
  pkgs,
  lib,
  osConfig,
  palette,
  inputs,
  ...
}:
let
  # Every colour below is a caelestia template field, not a colour: the files
  # they land in are rendered by caelestia on each scheme switch (see
  # hutao.caelestiaTemplates in caelestia.nix), so the apps follow the scheme
  # without a rebuild.
  inherit (palette.template)
    hex
    argb
    rgba
    colours
    ;

  src = ../../dotfiles;

  kittyColours = pkgs.writeText "mocha.conf" ''
    # vim:ft=kitty
    #
    # A caelestia template, rendered on every scheme switch. Was a hand-edited
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
      { "1f1d2e" = colours.surface0; }
      { "191724" = colours.base; }
      { "eb6f92" = colours.primary; }
      { "e0def4" = colours.text; }
      { "31748f" = colours.red; }
      { "9ccfd8" = colours.green; }
    ];

    "dot-config/mako/config" = [
      { "#330101" = hex.surfaceVariant; }
      { "#551111" = hex.overlay0; }
      { "#d08770" = hex.maroon; }
      { "#bf616a" = hex.red; }
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
      { "c8c5d1" = colours.subtext1; }
      { "190707" = colours.base; }
      { "d94f6e" = colours.term5; }
      { "eb6c6c" = colours.primary; }
      { "ab6670" = colours.mauve; }
      { "d3a891" = colours.flamingo; }
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

  # ~/.config/hypr is one store link (hyprland.nix), so look_and_feel.lua
  # cannot be a template itself; it dofile()s this one instead, and keeps its
  # own literals for when the rendered file is not there.
  hyprColours = pkgs.writeText "hypr-colours.lua" ''
    return {
      active_border = { "rgba(${argb "primary" "ee"})", "rgba(${argb "term5" "ee"})" },
      inactive_border = "rgba(${argb "outline" "aa"})",
      shadow = "rgba(${argb "crust" "ee"})",
    }
  '';

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

  inherit (osConfig.networking) hostName;

  # --replace-fail: break the build when a patch lands upstream.
  df = pkgs.runCommandLocal "hutao-dotfiles-${hostName}" { } ''
    cp -r ${src} $out
    chmod -R u+w $out

    # Someone else's art, so the private third-party-assets input carries it.
    # Copied back to where the tree used to hold it, which is the path
    # hyprpaper, hyprlock and the caelestia seed all read.
    mkdir -p $out/dot-config/hypr/backgrounds
    cp ${inputs.third-party-assets}/assets/third-party/Wallpapers/* \
      $out/dot-config/hypr/backgrounds/

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
    cp ${../../hosts + "/${hostName}/monitors.lua"} \
      $out/dot-config/hypr/modules/monitors.lua

    # ── Cursor ───────────────────────────────────────────────────────────
    # programs.lua is what the Hyprland side reads the pointer off, and
    # modules/desktop/cursor.nix is what the system side sets. Substituted
    # rather than kept in step by hand, so switching themes stays one line --
    # and --replace-fail means a drifted literal is a failed build, not a
    # desktop running two different cursors.
    substituteInPlace $out/dot-config/hypr/modules/programs.lua \
      --replace-fail 'cursor_theme = "Hutao-Cursor"' \
        'cursor_theme = "${osConfig.stylix.cursor.name}"' \
      --replace-fail 'cursor_size = 24' \
        'cursor_size = ${toString osConfig.stylix.cursor.size}'

    # ── Paths ────────────────────────────────────────────────────────────
    ${substPhase repath}

    # ── Colours ──────────────────────────────────────────────────────────
    cp ${kittyColours} $out/dot-config/mocha/mocha.conf

    ${substPhase recolour}

    # look_and_feel.lua's fallback, for when hypr-colours.lua is not rendered
    # yet: the scheme as of this build rather than literals from none.
    substituteInPlace $out/dot-config/hypr/modules/look_and_feel.lua \
      --replace-fail 'rgba(ff3333ee)' 'rgba(${palette.argb "primary" "ee"})' \
      --replace-fail 'rgba(ff0099ee)' 'rgba(${palette.argb "term5" "ee"})' \
      --replace-fail 'rgba(595959aa)' 'rgba(${palette.argb "outline" "aa"})' \
      --replace-fail 'rgba(1a1a1aee)' 'rgba(${palette.argb "crust" "ee"})'
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
    # opencode writes a .gitignore into its config dir on every boot; linked
    # whole, that write is EROFS and the TUI dies at startup.
    "dot-config/opencode"
    "dot-config/vesktop"
    "dot-config/vesktop/themes"
    "dot-local"
    "dot-local/share"
    "dot-local/share/icons"
  ];

  # Every file with a colour in it: `df` makes each a template, and the app's
  # path links to what caelestia renders from it instead of into `df`.
  templated = lib.attrNames recolour ++ [ "dot-config/mocha/mocha.conf" ];

  # caelestia renders templates by bare file name, so the path is flattened
  # into one: .config/waybar/style.css is waybar-style.css.
  templateName = p: lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix ".config/" (target p));

  # A link inside a linked directory is impossible, so every directory above
  # a templated file is walked entry by entry.
  ancestors =
    p:
    let
      parts = lib.splitString "/" p;
    in
    map (n: lib.concatStringsSep "/" (lib.take n parts)) (lib.range 1 (lib.length parts - 1));

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
      if
        builtins.elem name ignore
        || builtins.elem p ignore
        || builtins.elem p elsewhere
        || builtins.elem p templated
      then
        { }
      else if type == "directory" && builtins.elem p (expand ++ lib.concatMap ancestors templated) then
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
in
{
  _module.args.dotfiles = df;

  home.file = walk "";

  hutao.caelestiaTemplates =
    lib.listToAttrs (
      map (p: {
        name = templateName p;
        value = {
          source = "${df}/${p}";
          target = target p;
        };
      }) templated
    )
    // {
      "hypr-colours.lua".source = hyprColours;
    };
}
