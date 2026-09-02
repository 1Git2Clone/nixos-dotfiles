-- Required by hyprland.lua; gitignored upstream because it is per-machine.
-- Check names and modes with `hyprctl monitors all`.
--
--   ┌──────────────────┐  ┌──────────────────┐
--   │ HDMI-A-1  @60    │  │ DP-1 (main) @165 │
--   │ -1920x0          │  │ 0x0              │
--   └──────────────────┘  └──────────────────┘
hl.monitor({
  output = "DP-1",
  mode = "1920x1080@165",
  position = "0x0",
  scale = 1,
})

hl.monitor({
  output = "HDMI-A-1",
  mode = "1920x1080@60",
  position = "-1920x0",
  scale = 1,
})
