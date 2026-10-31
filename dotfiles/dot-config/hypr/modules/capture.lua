-- The store path is filled by home/apps/dotfiles.nix. Hyprland loads registered
-- plugins after parsing, then parses again with their Lua API available.
-- A switch can reload config into the previous release's running process.
if hl.version() ~= "@HYPRLAND_RELEASE@" then
  return
end
hl.plugin.load("@HYPRCAPTURE_PLUGIN@")
if not hl.plugin.hyprcapture then
  return
end

hl.config({
  plugin = {
    hyprcapture = {
      default_mode = "region",
      fullscreen_scope = "current",
      fusion_mode = true,
      window_background = "transparent",
      window_border = "keep",
      window_shadow = "keep",
      allow_quick = true,
      save = true,
      clipboard = true,
      show_thumbnail = true,
      save_dir = "$XDG_PICTURES_DIR/Screenshots",
      record_save_dir = "$XDG_VIDEOS_DIR/Screenrecords",
    },
  },
})
