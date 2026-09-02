# Hyprland + SDDM + Stylix, and every binary the dotfiles call. ~/.config
# itself is home/hutao.nix's job.
#
# That config is Lua (Hyprland 0.55+), so the package must be new enough to
# read hyprland.lua. nixos-unstable is.
{ inputs, pkgs, ... }:
let
  hutao-cursor = pkgs.callPackage ../pkgs/hutao-cursor.nix { };

  sddm-hu-tao = pkgs.callPackage ../pkgs/sddm-hu-tao.nix { };
in
{
  # ── Stylix ───────────────────────────────────────────────────────────────
  stylix = {
    enable = true;
    polarity = "dark";

    # Derived from caelestia/schemes/hu-tao/default/dark.txt.
    base16Scheme = ../hu-tao.yaml;

    # The one hyprpaper.conf names. base16Scheme above is explicit, so this is
    # only used as the wallpaper — nothing is derived from it.
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
      # Matches kitty.conf's font_size 9.0
      sizes = {
        terminal = 9;
        applications = 10;
        desktop = 10;
        popups = 10;
      };
    };

    opacity.terminal = 0.92;

    # Same theme env.lua's XCURSOR_THEME names, so the greeter matches.
    cursor = {
      package = hutao-cursor;
      name = "Hutao-Cursor";
      size = 24;
    };
  };

  # ── Hyprland ─────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;

  # No hypridle: caelestia's shell.json owns idle (general.idle.timeouts —
  # lock at 3min, dpms at 5, suspend-then-hibernate at 10). Running both
  # locks the session twice.

  # ── SDDM ─────────────────────────────────────────────────────────────────
  # Stylix has no sddm target (only lightdm and regreet), so the greeter is
  # themed by hand or it comes up stock blue.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;

    # Must match the package's directory name and its Theme-Id.
    theme = "sddm-hu-tao";

    # Main.qml's imports must reach the greeter; systemPackages is not enough.
    extraPackages = with pkgs.kdePackages; [
      qtsvg
      qtmultimedia
      qtvirtualkeyboard
    ];
  };

  # ── Audio ────────────────────────────────────────────────────────────────
  # wireplumber provides wpctl, which the XF86Audio* keybinds call.
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

  # autostart.lua execs these by absolute Arch path, which does not exist
  # here. Declared as services instead, so those lines fail harmlessly.
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.geoclue2.enable = true;

  # polkit-gnome has no NixOS option; this is the documented user-service form.
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
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    dejavu_fonts
    liberation_ttf
  ];

  # ── Packages ─────────────────────────────────────────────────────────────
  # required_packages_archlinux.txt plus everything the stowed scripts and
  # keybinds actually call; that list had drifted.
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

    # notifications used by 12 call sites across the scripts
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

    # misc from the Arch list
    ntfs3g
    pinentry-gnome3
    xauth
    xhost
  ];

  programs.gamemode.enable = true;
  services.power-profiles-daemon.enable = true; # powerprofilesctl, power-mode.sh

  # ydotool needs its daemon for the autoclicker scripts to work.
  programs.ydotool.enable = true;

  # oh-my-zsh loads autosuggestions and syntax-highlighting as plugins (see
  # home/hutao.nix), so the NixOS-level versions would be a second copy.
  #
  # ZSH_CACHE_DIR defaults to $ZSH/cache, and $ZSH is a store path here.
  environment.sessionVariables.ZSH_CACHE_DIR = "$HOME/.cache/oh-my-zsh";
}
