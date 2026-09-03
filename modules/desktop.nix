# Hyprland + SDDM + Stylix, and every binary the dotfiles call. ~/.config
# itself is home/hutao.nix's job.
#
# hyprland.lua needs Hyprland 0.55+, which is why this tracks unstable.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  hutao-cursor = pkgs.callPackage ../pkgs/hutao-cursor.nix { };

  app-icons = pkgs.callPackage ../pkgs/app-icons.nix { };

  sddm-hu-tao = pkgs.callPackage ../pkgs/sddm-hu-tao.nix { };
in
{
  # ── Stylix ───────────────────────────────────────────────────────────────
  stylix = {
    enable = true;
    polarity = "dark";

    # Derived from caelestia/schemes/hu-tao/default/dark.txt.
    base16Scheme = ../hu-tao.yaml;

    # Wallpaper only; base16Scheme above is explicit, so nothing derives
    # colours from this.
    image = "${inputs.dotfiles}/dot-config/hypr/backgrounds/Hu_Tao_00056_1.png";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      # kitty.conf's font_size.
      sizes = {
        terminal = 9;
        applications = 10;
        desktop = 10;
        popups = 10;
      };
    };

    opacity.terminal = 0.92;

    # The theme env.lua's XCURSOR_THEME names.
    cursor = {
      package = hutao-cursor;
      name = "Hutao-Cursor";
      size = 24;
    };
  };

  # Quickshell is Qt6. stylix's qt target installs qt6ct but sets
  # platformTheme = "qt5ct", so Qt hunts for libqt5ct.so among the Qt6 plugins,
  # loads no platform theme, and QIcon::themeName() comes back empty — every
  # app icon in caelestia's launcher goes missing.
  #
  # stylix's qt target is what installs the qt6ct plugin and puts
  # lib/qt-6/plugins on QT_PLUGIN_PATH. Disabling it removed the plugin while
  # leaving the theme name set, so Qt had a name and nowhere to load it from —
  # same broken end state, different cause. Keep the target and override only
  # the name, since it sets qt5ct and a Qt6 app cannot load libqt5ct.so.
  #
  # mkForce because the target defines this too. The NixOS qt module's
  # platformTheme enum has no qt6ct value, hence the raw variable.
  stylix.targets.qt.enable = true;
  environment.variables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";

  # ── Hyprland ─────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;

  # No hypridle: caelestia's general.idle.timeouts owns this, and running both
  # locks the session twice.

  # ── SDDM ─────────────────────────────────────────────────────────────────
  # Stylix has no sddm target, so the greeter is themed by hand.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;

    # Must match the package directory name and its Theme-Id.
    theme = "sddm-hu-tao";

    # Theme.CursorTheme only reaches the Qt greeter. On Wayland the compositor
    # draws the pointer, and weston takes its theme from [shell] cursor-theme in
    # weston.ini — it ignores XCURSOR_THEME. NixOS' generated ini has no [shell]
    # section at all, so weston asks for a theme literally named "default",
    # finds none, and draws no cursor.
    settings.Theme.CursorTheme = "Hutao-Cursor";

    wayland.compositorCommand =
      let
        westonIni = pkgs.writeText "weston.ini" ''
          [shell]
          cursor-theme=Hutao-Cursor
          cursor-size=24

          [keyboard]
          keymap_layout=us
          keymap_model=pc104
          keymap_options=terminate:ctrl_alt_bksp

          [libinput]
          enable-tap=true
        '';
      in
      "${pkgs.weston}/bin/weston --shell=kiosk -c ${westonIni}";

    # Main.qml's Qt imports; systemPackages does not reach the greeter.
    extraPackages = with pkgs.kdePackages; [
      qtsvg
      qtmultimedia
      qtvirtualkeyboard
    ];
  };

  # dot-gitconfig sets commit.gpgSign; without this every commit fails.
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  # ── Audio ────────────────────────────────────────────────────────────────
  # wireplumber ships wpctl, which the XF86Audio* keybinds call.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ── Portals ──────────────────────────────────────────────────────────────
  # dot-config/xdg-desktop-portal/hyprland-portals.conf asks for hyprland;gtk.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # autostart.lua execs these by Arch path. Declared as services so those
  # lines fail harmlessly.
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.geoclue2.enable = true;

  # polkit-gnome has no NixOS option.
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  # mpris-proxy (autostart.lua) ships with bluez.
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── Japanese input — from fcitx5-mozc in the Arch package list ───────────
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    # Otherwise the module exports GTK_IM_MODULE/QT_IM_MODULE and fcitx5 warns
    # that it found them alongside a working Wayland frontend. Uses the
    # text-input protocol instead, which Hyprland speaks.
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
  };

  fonts.packages = with pkgs; [
    # caelestia names its icons "calculate", "palette", "power_settings_new" —
    # Material Symbols glyphs. Without the font they render as nothing.
    material-symbols
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    dejavu_fonts
    liberation_ttf
  ];

  # ── Packages ─────────────────────────────────────────────────────────────
  # required_packages_archlinux.txt, plus what the scripts and keybinds
  # actually call — that list had drifted.
  environment.systemPackages = with pkgs; [
    # terminal / file manager  (neovim is in modules/neovim.nix)
    kitty
    nautilus
    floorp-bin

    # Installed so SDDM finds it under /run/current-system/sw.
    sddm-hu-tao

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

    # autoclicker.sh / sckey.sh
    ydotool

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
    bluez # mpris-proxy, in autostart.lua
    nano

    # shell / cli  (from the Arch list)
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
    unzip
    git
    git-lfs

    # dev
    clang
    nodejs

    # gaming
    mangohud
    gamemode

    # dot-gitconfig's credential helpers. GCM is usable here only because `df`
    # rewrites credentialStore to secretservice — gpg needs a ~/.password-store
    # that does not exist, and GCM then fails hard instead of prompting.
    gh
    git-credential-manager

    # The theme dot-config/hypr/hyprqt6engine.conf already names. qt6ct is what
    # reads it; stylix used to pull it in as a side effect of its qt target.
    papirus-icon-theme
    qt6Packages.qt6ct

    # Hutao-Cursor's index.theme says Inherits=Adwaita, and Adwaita was not
    # installed — so any shape it lacks resolved to nothing. This is the
    # guaranteed floor: it ships cursors/default and cursors/left_ptr.
    adwaita-icon-theme

    # caelestia's launcher favourites reference both.
    vesktop

    ente-auth

    # misc from the Arch list
    ntfs3g
    pinentry-gnome3
    xauth
    xhost

    # let-bound above; a `let` binding shadows `with pkgs`. Here so the SDDM
    # greeter resolves the cursor theme.
    hutao-cursor

    # Icons for the hand-written ~/.local/share/applications entries.
    app-icons
  ];

  # Not a systemPackages entry: steam needs the FHS wrapper and the udev rules
  # this option installs.
  programs.steam.enable = true;

  programs.gamemode.enable = true;
  services.power-profiles-daemon.enable = true; # powerprofilesctl, power-mode.sh

  # The autoclicker scripts need ydotool's daemon.
  programs.ydotool.enable = true;

  # oh-my-zsh already loads autosuggestions and syntax-highlighting as plugins
  # (home/hutao.nix), so the NixOS-level options would be a second copy.
  #
  # ZSH_CACHE_DIR defaults to $ZSH/cache, and $ZSH is a store path here.
  environment.sessionVariables.ZSH_CACHE_DIR = "$HOME/.cache/oh-my-zsh";
}
