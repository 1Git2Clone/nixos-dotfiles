local home = os.getenv("HOME") or "~"
local xdg_data_dirs = home
  .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"

return {
  terminal = "kitty",
  file_manager = "nautilus -w",
  menu = "export XDG_DATA_DIRS=" .. xdg_data_dirs .. " && wofi --show drun",
  xdg_data_dirs = xdg_data_dirs,
  -- By name, because a rebuild restarts the shell with it too
  -- (home/apps/caelestia.nix), through `hyprctl eval`.
  shell = "QT_QPA_PLATFORMTHEME=hyprqt6engine XDG_DATA_DIRS=" .. xdg_data_dirs .. " caelestia shell -d",
  cursor_theme = "Hutao-Cursor",
  cursor_size = 24,
}
