local M = {}

function M.setup(programs)
  -- programs.lua owns these; autostart.lua's setcursor reads the same two, so
  -- a theme swap is one edit there rather than five literals across two files.
  hl.env("XCURSOR_THEME", programs.cursor_theme)
  hl.env("XCURSOR_SIZE", tostring(programs.cursor_size))
  hl.env("HYPRCURSOR_THEME", programs.cursor_theme)
  hl.env("HYPRCURSOR_SIZE", tostring(programs.cursor_size))

  hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
  hl.env("QT_QPA_PLATFORM", "wayland")
  hl.env("SDL_VIDEODRIVER", "wayland")
  hl.env("CLUTTER_BACKEND", "wayland")
  hl.env("MOZ_ENABLE_WAYLAND", "1")
  hl.env("NIXOS_OZONE_WL", "1")
  hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
  hl.env("QT_STYLE_OVERRIDE", "adwaita")
  hl.env("XDG_DATA_DIRS", programs.xdg_data_dirs)
end

return M
