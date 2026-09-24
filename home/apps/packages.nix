# Everything the keybinds, scripts and dotfiles call that is not an app with
# config of its own -- those have their own file beside this one.
{ inputs, pkgs, ... }:
let
  app-icons = pkgs.callPackage ../../pkgs/app-icons.nix { };
  openrouter-image-mcp = pkgs.callPackage ../../pkgs/openrouter-image-mcp.nix { };

  # ktailctl names no QtQuick Controls style of its own, so Kirigami loads the
  # Basic one -- which has hardcoded light colours and never reads the
  # kdeglobals apps/theme.nix writes. Hence a white window on a dark desktop.
  # org.kde.desktop is the style that does read it, and it already sits in
  # ktailctl's own closure (qqc2-desktop-style, lib/qt-6/qml/org/kde/desktop).
  #
  # Wrapped per app rather than set session-wide: caelestia-shell imports
  # QtQuick.Controls too -- bar popouts, tray menu, calendar -- so a global
  # QT_QUICK_CONTROLS_STYLE would drag the bar into this style along with it.
  # The desktop entry is `Exec=ktailctl`, a bare name off PATH, so the
  # launcher finds this wrapper rather than walking past it.
  ktailctl = pkgs.symlinkJoin {
    name = "ktailctl-${pkgs.ktailctl.version}";
    paths = [ pkgs.ktailctl ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/ktailctl \
        --set QT_QUICK_CONTROLS_STYLE org.kde.desktop
    '';
  };

in
{
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
    inputs.workmux.packages.${pkgs.system}.default
    inputs.cli-utils.packages.${pkgs.system}.default

    # MCP servers. Both agents spawn these by bare name -- neither expands `~`
    # in a command, so a path in their config is a path that never resolves.
    inputs.codebase-memory-mcp.packages.${pkgs.system}.default
    openrouter-image-mcp
    playwright-mcp

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

    # Libreoffice
    libreoffice-fresh

    # Google
    google-chrome

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
    modrinth-app
    osu-lazer-bin
    # The JREs are deliberately not here: any two temurin builds collide on
    # legal/jdk.localedata/cldr.md and buildEnv refuses. Both are linked below.

    # GCM works here only because `df` rewrites credentialStore to
    # secretservice; gpg wants a ~/.password-store that does not exist.
    gh
    forgejo-cli # `fj`
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

    # Tray GUI for tailscaled, kept for its exit-node menu (Mullvad nodes get
    # their own per-country submenu). Exit nodes are stored prefs, so picking
    # one here is runtime state and never wants a rebuild. Let-bound above for
    # the style wrapper; a `let` binding shadows `with pkgs`.
    ktailctl

    # misc from the Arch list
    xauth
    xhost

    # let-bound above; a `let` binding shadows `with pkgs`.
    app-icons
  ];

  # Outside the profile there is no collision, and these paths stay put while
  # the store hash behind them moves -- which is what Modrinth's "add Java
  # version" dialog needs, since it only ever finds one `java` on PATH itself.
  home.file.".local/share/jres/21".source = pkgs.temurin-jre-bin-21;
  home.file.".local/share/jres/25".source = pkgs.temurin-jre-bin-25;

  # Bare `java` outside Modrinth; 21 is reachable by full path above.
  home.sessionPath = [ "$HOME/.local/share/jres/25/bin" ];
}
