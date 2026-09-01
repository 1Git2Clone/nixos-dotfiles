--[[
Laptop-only monitor config for hutao-laptop (Lenovo IdeaPad 1 15AMN7, 15.6" FHD).

WHY THIS FILE IS HERE, NOT STOWED
---------------------------------
dot-config/hypr/modules/monitors.lua is gitignored in the dotfiles repo (it is
setup-specific). But hyprland.lua does:

    require("modules.monitors")

So on a freshly-stowed machine that file does not exist and Hyprland fails to
load its config — you get a bare compositor with no keybinds.

Copy this into place AFTER stowing:

    cp ~/nixos-dotfiles/reference/monitors.lua \
       ~/dotfiles/dot-config/hypr/modules/monitors.lua

It goes in the dotfiles repo (where it stays gitignored), not in ~/.config
directly, because stow owns that path.

Verify the panel's real name and modes first:
    hyprctl monitors all
--]]

hl.monitor({
  output = "eDP-1",
  mode = "1920x1080@60",
  position = "0x0",
  scale = 1,
})
