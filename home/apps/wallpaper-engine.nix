# Wallpaper Engine's Steam Workshop wallpapers, animated, through
# linux-wallpaperengine and a GUI for picking them. Both read the assets out of
# the Steam install, so Wallpaper Engine itself has to be owned and installed.
#
# caelestia's wallpaper stays on, on the Background layer, and the engine draws
# on Bottom above it -- so a monitor with no engine wallpaper keeps
# caelestia's. The static pick still drives the scheme, stylix and SDDM.
{ pkgs, ... }:
let
  gui = pkgs.callPackage ../../pkgs/linux-wallpaperengine-gui.nix { };
in
{
  home.packages = [ gui ];

  # The GUI's own autostart toggle writes an XDG autostart entry, which nothing
  # here runs: SDDM starts Hyprland without uwsm, so
  # xdg-desktop-autostart.target never starts. --minimized starts the tray
  # alone, and the backend replays the last wallpaper.
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
