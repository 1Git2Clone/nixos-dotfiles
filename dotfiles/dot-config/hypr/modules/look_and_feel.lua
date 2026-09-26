-- Colours come from the caelestia scheme, rendered on every switch (see
-- home/apps/dotfiles.nix, hypr-colours.lua); these literals are the fallback
-- for when that file is not there.
local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local ok, scheme = pcall(dofile, state .. "/caelestia/theme/hypr-colours.lua")
local colours = ok and scheme
  or {
    active_border = { "rgba(ff3333ee)", "rgba(ff0099ee)" },
    inactive_border = "rgba(595959aa)",
    shadow = "rgba(1a1a1aee)",
  }

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    col = {
      active_border = { colors = colours.active_border, angle = 235 },
      inactive_border = colours.inactive_border,
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
  },

  cursor = {
    -- hyprcursor is the only format Hyprland renders this artwork in, and
    -- the theme now ships one: pkgs/hutao-cursor.nix builds a hyprcursor
    -- half beside the XCursor one. The old note here was right that
    -- hyprcursor mode drew a default cursor -- the theme had no hyprcursor
    -- data, because hyprcursor rejects the spaces in shape names like
    -- "13-Diagonal Resize 1". XCursor mode drew a default cursor too, which
    -- is what left the whole desktop on Adwaita's arrow while slurp, which
    -- loads the XCursor half itself, was the one place Hu Tao showed up.
    enable_hyprcursor = true,
  },

  decoration = {
    rounding = 20,
    rounding_power = 2,
    active_opacity = 0.96,
    inactive_opacity = 0.88,

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = colours.shadow,
    },

    blur = {
      enabled = true,
      size = 3,
      passes = 1,
      vibrancy = 0.1696,
    },
  },

  dwindle = {
    preserve_split = true,
  },

  master = {
    new_status = "master",
  },

  misc = {
    force_default_wallpaper = -1,
    disable_hyprland_logo = false,
  },
})
