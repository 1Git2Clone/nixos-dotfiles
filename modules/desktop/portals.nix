# dot-config/xdg-desktop-portal/hyprland-portals.conf asks for hyprland;gtk.
{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # kitty's kitty-open.desktop claims inode/directory, so a file dialog's
  # "open folder" (or any xdg-open on a directory) launched a terminal.
  # /etc/xdg sits under ~/.config/mimeapps.list, which apps keep writing to.
  xdg.mime.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
}
