local M = {}

function M.setup(programs)
  hl.on("hyprland.start", function()
    -- xdg-desktop-portal has Requisite=graphical-session.target, which refuses
    -- to start rather than pulling the target in. NixOS skips starting it for
    -- us because XDG_CURRENT_DESKTOP names Hyprland, whose sessions normally
    -- do it themselves under uwsm. Without this there is no ScreenCast portal
    -- and screen sharing silently does nothing.
    hl.exec_cmd(
      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
        .. " && systemctl --user start nixos-fake-graphical-session.target"
    )

    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    hl.exec_cmd("trash-empty 30")

    hl.exec_cmd("hyprctl setcursor " .. programs.cursor_theme .. " " .. programs.cursor_size)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme '" .. programs.cursor_theme .. "'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. programs.cursor_size)

    hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")
    hl.exec_cmd("sleep 1 && gammastep")

    hl.exec_cmd("mpris-proxy")

    hl.exec_cmd("caelestia resizer -d")
    hl.exec_cmd("QT_QPA_PLATFORMTHEME=hyprqt6engine XDG_DATA_DIRS=" .. programs.xdg_data_dirs .. " caelestia shell -d")

    hl.exec_cmd("fcitx5")
    hl.exec_cmd("espanso start")

    hl.exec_cmd("~/dotfiles/dot-config/programs/shell_scripts/usb-device-connect.sh")
  end)
end

return M
