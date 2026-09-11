# dot-config/xdg-desktop-portal/hyprland-portals.conf asks for hyprland;gtk.
{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
