# Hyprland + SDDM + Stylix, and the system side of what the dotfiles need.
# The binaries themselves are home/hutao.nix's home.packages, and so is
# ~/.config.
#
# hyprland.lua needs Hyprland 0.55+, which is why this tracks unstable.
{
  lib,
  pkgs,
  ...
}:
let
  hutao-cursor = pkgs.callPackage ../pkgs/hutao-cursor.nix { };

  palette = import ../palette.nix { inherit lib; };

  sddm-hu-tao = pkgs.callPackage ../pkgs/sddm-hu-tao.nix { inherit palette; };
in
{
  # ── Stylix ───────────────────────────────────────────────────────────────
  stylix = {
    enable = true;
    polarity = "dark";

    # The 16 slots read straight out of the caelestia scheme by their
    # semantic names, so this and the shell cannot drift. See palette.nix.
    base16Scheme = palette.base16;

    # Wallpaper only; base16Scheme above is explicit, so nothing derives
    # colours from this.
    image = ../dotfiles/dot-config/hypr/backgrounds/Hu_Tao_00056_1.png;

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

  # stylix's qt target sets platformTheme = "qt5ct", which a Qt6 app cannot
  # load — QIcon::themeName() comes back empty and caelestia's launcher icons
  # all vanish. Keep the target, which is what installs the plugin and puts
  # lib/qt-6/plugins on QT_PLUGIN_PATH, and override only the name. Raw
  # variable and mkForce: the NixOS enum has no qt6ct value, and the target
  # defines this too.
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

    # Theme.CursorTheme only reaches the Qt greeter. On Wayland weston draws
    # the pointer and reads [shell] cursor-theme, ignoring XCURSOR_THEME — and
    # the generated ini has no [shell] section, so it draws no cursor at all.
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

  # The web app talks to a local streaming server on 11470/12470, and nothing
  # starts it: the package ships only a binary and a .desktop, and nixpkgs has
  # no services.stremio-service. Without this the web app just says
  # "Streaming server is not available".
  systemd.user.services.stremio-service = {
    description = "Stremio streaming server";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.stremio-service}/bin/stremio-service";
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

    # Otherwise the module exports GTK_IM_MODULE/QT_IM_MODULE and fcitx5
    # warns; the text-input protocol Hyprland speaks is enough.
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
  };

  fonts.packages = with pkgs; [
    # caelestia's icon names are Material Symbols glyphs.
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
  # Only what a user profile cannot reach. Everything the keybinds, scripts
  # and dotfiles call is home/hutao.nix's home.packages instead -- with
  # useUserPackages that lands in /etc/profiles/per-user/hutao, and
  # environment.profiles already puts that on PATH, XDG_DATA_DIRS,
  # XCURSOR_PATH and QT_PLUGIN_PATH, so a user-profile package is found
  # exactly like a system one.
  environment.systemPackages = with pkgs; [
    # The greeter runs as `sddm`, so none of the per-user profile paths are
    # set for it -- the theme and the cursor it names have to be here.
    # Let-bound above; a `let` binding shadows `with pkgs`.
    sddm-hu-tao
    hutao-cursor

    # mount resolves its mount.ntfs helper off root's PATH.
    ntfs3g

    # sgdisk and parted. disko's own scripts carry both on their PATH, which
    # is why the script partitions fine and a shell cannot. Run under sudo,
    # so a user profile is the wrong place for them.
    gptfdisk
    parted
  ];

  # The option, not the package: steam needs the FHS wrapper and udev rules.
  programs.steam.enable = true;

  # Shows up in the compatibility dropdown as dwproton-11.0-12. Via this
  # option and not systemPackages, which is what the package's own meta says
  # and what puts it on STEAM_EXTRA_COMPAT_TOOLS_PATHS -- so it lives in the
  # store rather than being downloaded into a library.
  programs.steam.extraCompatPackages = [ pkgs.dwproton-bin ];

  programs.gamemode.enable = true;
  services.power-profiles-daemon.enable = true; # powerprofilesctl, power-mode.sh

  # The autoclicker scripts need ydotool's daemon.
  programs.ydotool.enable = true;

  # oh-my-zsh already loads these as plugins (home/hutao.nix), and
  # ZSH_CACHE_DIR defaults to $ZSH/cache, which is a store path here.
  environment.sessionVariables.ZSH_CACHE_DIR = "$HOME/.cache/oh-my-zsh";
}
