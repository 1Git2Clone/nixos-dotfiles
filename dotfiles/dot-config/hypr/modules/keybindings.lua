local M = {}

local function exec(cmd)
  return hl.dsp.exec_cmd(cmd)
end

-- I hate having a mac
local function mac_bind(key, shift)
  hl.bind(
    "ALT" .. (shift and " + SHIFT" or "") .. " + " .. key,
    hl.dsp.send_shortcut({
      mods = shift and "CTRL,SHIFT" or "CTRL",
      key = key,
    })
  )
end

local function firefox_emacs_bind(keys, mods, key)
  hl.bind(keys, function()
    local window = hl.get_active_window()

    if window and (window.class == "firefox" or window.class == "floorp") then
      -- No window selector: a class regex resolves to the first match in the
      -- window list, not the focused one, so a second Floorp window steals it.
      hl.dispatch(hl.dsp.send_shortcut({
        mods = mods,
        key = key,
      }))
      return { ok = true }
    end

    return { ok = false }
  end, {
    auto_consuming = true,
    repeating = true,
  })
end

function M.setup(programs)
  local main_mod = "SUPER"
  local file_manager_from_clipboard = 'sh -c \'c=$(wl-paste); [ -d "$c" ] && '
    .. programs.file_manager
    .. ' "$c" || '
    .. programs.file_manager
    .. "'"
  local neovide_from_clipboard = 'sh -c \'c=$(wl-paste); [ -d "$c" ] && neovide "$c" || neovide\''
  local launcher_interrupt_opts = { ignore_mods = true, non_consuming = true }

  hl.define_submap("global", function()
    hl.bind(main_mod .. " + Q", exec(programs.terminal))
    hl.bind(main_mod .. " + Return", exec(programs.terminal))
    hl.bind(main_mod .. " + SHIFT + C", hl.dsp.window.close())
    hl.bind(main_mod .. " + M", exec("wlogout --protocol layer-shell"))
    hl.bind(main_mod .. " + E", exec(file_manager_from_clipboard))
    hl.bind(main_mod .. " + SHIFT + E", exec(neovide_from_clipboard))
    hl.bind(main_mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(main_mod .. " + V", hl.dsp.window.center())
    hl.bind(main_mod .. " + P", hl.dsp.window.pseudo())
    hl.bind(main_mod .. " + G", hl.dsp.layout("togglesplit"))
    hl.bind(main_mod .. " + Space", exec(programs.menu))

    hl.bind(main_mod .. " + SUPER_L", hl.dsp.global("caelestia:launcher"), { ignore_mods = true, release = true })

    for _, key in ipairs({
      "Q",
      "Return",
      "C",
      "E",
      "G",
      "V",
      "S",
      "Space",
      "mouse:274",
      "mouse:275",
      "mouse:276",
      "mouse:277",
      "mouse_up",
      "mouse_down",
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "0",
    }) do
      hl.bind(main_mod .. " + " .. key, hl.dsp.global("caelestia:launcherInterrupt"), launcher_interrupt_opts)
    end

    mac_bind("A")
    mac_bind("C")
    mac_bind("C", true)
    mac_bind("V")
    mac_bind("V", true)
    mac_bind("Z")
    mac_bind("Z", true)
    mac_bind("S")
    mac_bind("S", true)
    -- New tab
    mac_bind("T")
    -- Restore last closed tab
    mac_bind("T", true)
    -- Close tab
    mac_bind("W")
    -- Find
    mac_bind("F")
    -- Next search result
    mac_bind("G")
    -- Previous search result
    mac_bind("G", true)
    -- Delete previous word
    mac_bind("BACKSPACE")
    hl.bind("ALT + CTRL + SPACE", exec("caelestia emoji -p"))
    hl.bind("ALT + CTRL + Q", exec("caelestia shell lock lock"))
    -- hl.bind("ALT + LEFT", hl.dsp.focus({ workspace = "e-1" }))
    -- hl.bind("ALT + RIGHT", hl.dsp.focus({ workspace = "e+1" }))

    -- Ctrl+J/K → Arrow Down/Up in Firefox
    firefox_emacs_bind("CTRL + J", "", "DOWN")
    firefox_emacs_bind("CTRL + K", "", "UP")

    -- Ctrl+N/P → Arrow Down/Up in Firefox
    firefox_emacs_bind("CTRL + N", "", "DOWN")
    firefox_emacs_bind("CTRL + P", "", "UP")

    -- Alt+N/P/J/K → original Ctrl+N/P/J/K in Firefox
    firefox_emacs_bind("ALT + N", "CTRL", "N")
    firefox_emacs_bind("ALT + P", "CTRL", "P")
    firefox_emacs_bind("ALT + J", "CTRL", "J")
    firefox_emacs_bind("ALT + K", "CTRL", "K")

    hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen())
    hl.bind(main_mod .. " + S", exec("screenshot-selection-copy.sh"))
    hl.bind(
      main_mod .. " + SHIFT + S",
      exec("screenshot-focused-monitor.sh")
    )
    hl.bind(main_mod .. " + CTRL + V", exec("cliphist list | wofi -dmenu | cliphist decode | wl-copy"))
    hl.bind(main_mod .. " + CTRL + C", exec("cliphist-remove-entry.sh"))
    -- hl.bind("CTRL + ALT + C", exec("get-cursor-pos.sh"))
    hl.bind("CTRL + ALT + T", exec([[kitty --class "floating-term"]]))
    hl.bind(main_mod .. " + T", exec("tesseract-screenshot.sh"))
    hl.bind(
      main_mod .. " + SHIFT + T",
      exec("tesseract-screenshot.sh eng")
    )
    hl.bind("ALT + E", exec("caelestia emoji -p"))
    hl.bind(main_mod .. " + SHIFT + P", exec("power-mode.sh"))
    hl.bind("CTRL + " .. main_mod .. " + J", exec("autoclicker.sh"))

    hl.bind(main_mod .. " + left", hl.dsp.focus({ direction = "left" }))
    hl.bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(main_mod .. " + up", hl.dsp.focus({ direction = "up" }))
    hl.bind(main_mod .. " + down", hl.dsp.focus({ direction = "down" }))
    hl.bind(main_mod .. " + l", hl.dsp.focus({ direction = "right" }))
    hl.bind(main_mod .. " + h", hl.dsp.focus({ direction = "left" }))
    hl.bind(main_mod .. " + k", hl.dsp.focus({ direction = "down" }))
    hl.bind(main_mod .. " + j", hl.dsp.focus({ direction = "up" }))

    for workspace = 1, 10 do
      local key = workspace % 10
      hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
      hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
    end

    hl.bind(main_mod .. " + D", hl.dsp.workspace.toggle_special())

    hl.bind(main_mod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "left" }))
    hl.bind(main_mod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
    hl.bind(main_mod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "up" }))
    hl.bind(main_mod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "down" }))
    hl.bind(main_mod .. " + SHIFT + h", hl.dsp.window.swap({ direction = "left" }))
    hl.bind(main_mod .. " + SHIFT + l", hl.dsp.window.swap({ direction = "right" }))
    hl.bind(main_mod .. " + SHIFT + k", hl.dsp.window.swap({ direction = "up" }))
    hl.bind(main_mod .. " + SHIFT + j", hl.dsp.window.swap({ direction = "down" }))

    hl.bind(main_mod .. " + G", hl.dsp.window.center())

    hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

    hl.bind(
      "XF86AudioRaiseVolume",
      exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
      { locked = true, repeating = true }
    )
    hl.bind(
      "XF86AudioLowerVolume",
      exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
      { locked = true, repeating = true }
    )
    hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
    hl.bind(
      "XF86AudioMicMute",
      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
      { locked = true, repeating = true }
    )
    hl.bind("XF86MonBrightnessUp", exec("brightnessctl s 10%+"), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", exec("brightnessctl s 10%-"), { locked = true, repeating = true })

    hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true })
    hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })
  end)

  -- submap_universal keeps these active regardless of the current submap,
  -- since we switch into the "global" submap on start/reload (see below) and
  -- the default "" submap these were previously relying on then goes dead.
  hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, submap_universal = true })
  hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, submap_universal = true })

  local function enter_global_submap()
    hl.exec_cmd([[hyprctl dispatch 'hl.dsp.submap("global")']])
  end

  hl.on("hyprland.start", enter_global_submap)
  hl.on("config.reloaded", enter_global_submap)
end

return M
