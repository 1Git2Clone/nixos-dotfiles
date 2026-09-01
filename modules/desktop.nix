# Hyprland + SDDM + Stylix.
#
# Vanilla Hyprland on purpose — your existing hypr configs keep coming from
# stow, exactly as on Arch. Nothing here writes to ~/.config.
#
# Stylix at the NixOS level themes SDDM, the TTY console, GTK/Qt system
# theming, cursors and fonts. App-level theming (kitty, neovim) needs the
# home-manager module — a separate decision, not smuggled in here.
{ pkgs, ... }:
{
  # ── Stylix ───────────────────────────────────────────────────────────────
  stylix = {
    enable = true;
    polarity = "dark";

    # Your own scheme, derived from
    # dotfiles: caelestia/schemes/hu-tao/default/dark.txt
    base16Scheme = ../hu-tao.yaml;

    # Placeholder: a solid base00 field so the config always evaluates.
    # Drop a real wallpaper in and point this at it — Stylix can also derive
    # the whole palette from an image if you'd rather, by removing
    # base16Scheme above.
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
  };

  # ── Hyprland ─────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;
  services.hypridle.enable = true;

  # ── SDDM ─────────────────────────────────────────────────────────────────
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # ── Audio ────────────────────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Portals ──────────────────────────────────────────────────────────────
  # Screen sharing and file pickers under Wayland. programs.hyprland already
  # pulls xdg-desktop-portal-hyprland; gtk covers the rest.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ── Japanese input — from your fcitx5-mozc setup ─────────────────────────
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      fcitx5-configtool
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];

  # ── Desktop packages — the subset of your Arch list that applies ─────────
  environment.systemPackages = with pkgs; [
    kitty
    hyprpaper
    hyprshot
    nautilus
    neovim
    neovide
    lazygit
    fastfetch
    mangohud
    gamemode
    wl-clipboard
    brightnessctl
    playerctl
    pavucontrol
  ];

  programs.gamemode.enable = true;

  services.power-profiles-daemon.enable = true;
}
