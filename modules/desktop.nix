# Hyprland + SDDM + Stylix.
#
# Hyprland itself is vanilla: hyprland.lua and modules/*.lua keep coming from
# stow, exactly as on Arch. Nothing here writes to ~/.config.
#
# NOTE: the stowed config is Lua (Hyprland 0.55+ "Luaification"), so the
# Hyprland package must be new enough to read hyprland.lua. nixos-unstable is.
{ pkgs, ... }:
let
  # Vendored from the dotfiles repo — see pkgs/hutao-cursor.nix for why it is
  # a package rather than a stowed directory.
  hutao-cursor = pkgs.callPackage ../pkgs/hutao-cursor.nix { };

  # The greeter theme. Vendored, not pkgs.sddm-astronaut — see
  # assets/sddm-hu-tao/ORIGIN.md.
  sddm-hu-tao = pkgs.callPackage ../pkgs/sddm-hu-tao.nix { };
in
{
  # ── Stylix ───────────────────────────────────────────────────────────────
  stylix = {
    enable = true;
    polarity = "dark";

    # Your own scheme, derived from
    # dotfiles: caelestia/schemes/hu-tao/default/dark.txt
    base16Scheme = ../hu-tao.yaml;

    # Placeholder: a solid base00 field so the config always evaluates.
    # Your real wallpapers live in dot-config/hypr/backgrounds/ — point this
    # at one once the dotfiles are stowed, e.g.
    #   image = /home/hutao/.config/hypr/backgrounds/Hu_Tao_1.png;
    image = pkgs.runCommand "hu-tao-bg.png" { } ''
      ${pkgs.imagemagick}/bin/magick -size 2560x1440 xc:'#130a0c' $out
    '';

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

    # env.lua sets XCURSOR_THEME=Hutao-Cursor. That used to be a stowed
    # directory in ~/.local/share/icons, which meant Stylix had nothing real to
    # point at and SDDM never saw the theme at all. It is a package now, so the
    # env var and Stylix finally name the same thing and the greeter matches
    # the session.
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
  services.hypridle.enable = true;

  # ── SDDM ─────────────────────────────────────────────────────────────────
  # Stylix cannot theme SDDM — there is no stylix.targets.sddm, only lightdm
  # and regreet — so the greeter is themed by hand. Without this it comes up
  # in stock blue while the session behind it is on the hu-tao palette, which
  # is exactly what the first rehearsal boot showed.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;

    # Matches the directory name the package installs and the Theme-Id in its
    # metadata.desktop. SDDM falls back to its default silently if this does
    # not resolve, so a mismatch reads as "the theme did not apply".
    theme = "sddm-hu-tao";

    # Main.qml imports QtMultimedia and QtQuick.VirtualKeyboard, and the icons
    # in Assets/ are SVG. These have to be visible to the greeter process
    # itself; putting them in systemPackages is not enough.
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
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ── Services that autostart.lua starts by absolute Arch path ─────────────
  # autostart.lua execs /usr/lib/polkit-gnome/... and /usr/lib/geoclue-2.0/...
  # Neither path exists on NixOS. Declaring the services here means they are
  # already running, so those two exec_cmd lines simply fail harmlessly.
  # See README — they can be deleted from autostart.lua.
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
  # Ported from required_packages_archlinux.txt, PLUS everything the stowed
  # shell scripts and keybinds actually call. The Arch list had drifted —
  # ydotool, grim, slurp, swappy, tesseract, cliphist, wlogout, espanso and
  # gammastep are all used by dot-config/programs/shell_scripts but were
  # never recorded in it.
  environment.systemPackages = with pkgs; [
    # terminal / file manager  (programs.lua)
    # neovim and neovide live in modules/neovim.nix, with the LSP and
    # formatter toolchain they need.
    kitty
    nautilus

    # The greeter theme has to be installed for SDDM to find it under
    # /run/current-system/sw/share/sddm/themes.
    sddm-hu-tao

    # launcher + session  (keybindings.lua: SUPER+Space, SUPER+M)
    wofi
    wlogout

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
    espanso
    trash-cli # trash-empty
    glib # gsettings

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

  # zsh plugins from the Arch list (zsh itself is enabled in users.nix).
  programs.zsh = {
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };
}
