# Wallpaper Engine's Steam Workshop wallpapers, animated, through
# linux-wallpaperengine and a GUI for picking them. Both read the assets out of
# the Steam install, so Wallpaper Engine itself has to be owned and installed,
# and a wallpaper subscribed to, on each machine.
#
# caelestia's wallpaper stays on, on the Background layer, and the engine draws
# on Bottom above it -- so a monitor with no engine wallpaper keeps
# caelestia's. The static pick still drives the scheme, stylix and SDDM.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  gui = pkgs.callPackage ../../pkgs/linux-wallpaperengine-gui.nix { };

  # Workshop IDs by output, for both machines: the GUI only starts the ones
  # that are connected. eDP-1 is the laptop's own panel, the same screen the
  # desktop streams LAPTOP to.
  wallpapers = rec {
    DP-1 = "2954387038"; # Hu Tao (Genshin Impact) [Animated, 4K]
    HDMI-A-1 = "2383527654"; # Hu Tao <3
    LAPTOP = "3014425829"; # 胡桃Hu Tao-忧心忡忡2k
    eDP-1 = LAPTOP;
  };

  # Ours over the GUI's: everything else in its config.json -- filters,
  # properties, the UI -- stays the GUI's to write.
  settings = (pkgs.formats.json { }).generate "linux-wallpaperengine-gui.json" {
    screens = lib.mapAttrsToList (name: wallpaper: {
      inherit name wallpaper;
      playlist = "";
    }) wallpapers;
    # The GUI's own defaults plus the desktop's HDD library, which it finds
    # Wallpaper Engine and the Workshop in. A path that doesn't exist is
    # skipped, so the laptop is unaffected.
    steamPaths = [
      ".local/share/Steam"
      ".var/app/com.valvesoftware.Steam/.local/share/Steam"
      ".steam/steam"
      ".steam/root"
      "/mnt/hdd/SteamLibrary"
    ];
    # Its "default" leaves a scene smaller than the screen at its own size and
    # clamps the edge pixels out to the borders.
    scaling = "fill";
    # The engine otherwise pauses for a fullscreen window on any workspace of
    # any monitor, and draws one frame until it goes.
    fullscreenPauseOnlyActive = true;
    # An XDG autostart entry, which nothing here runs; the service below is
    # what starts it.
    autostart = false;
  };
in
{
  home.packages = [ gui ];

  # jq's * replaces arrays whole, so `screens` is exactly the set above; a
  # wallpaper picked in the GUI lasts until the next rebuild. The GUI rereads
  # config.json on every apply, so nothing needs restarting.
  home.activation.wallpaperEngineSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    conf="${config.xdg.configHome}/linux-wallpaperengine-gui/config.json"
    run mkdir -p "$(dirname "$conf")"
    if [ -s "$conf" ]; then
      run ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$conf" ${settings} > "$conf.tmp"
      run mv "$conf.tmp" "$conf"
    else
      run install -m644 ${settings} "$conf"
    fi
  '';

  # SDDM starts Hyprland without uwsm, so xdg-desktop-autostart.target never
  # starts. --minimized starts the backend in the tray alone, and it applies
  # the screens above.
  systemd.user.services.linux-wallpaperengine-gui = {
    Unit = {
      Description = "Wallpaper Engine wallpaper, restored at login";
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      # The engine picks its window server off this and exits without it, and
      # autostart.lua imports only WAYLAND_DISPLAY and friends into systemd.
      Environment = [ "XDG_SESSION_TYPE=wayland" ];
      ExecStart = "${gui}/bin/linux-wallpaperengine-gui --minimized";
      Restart = "on-failure";
    };
  };
}
