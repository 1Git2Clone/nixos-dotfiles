# `shell-notify watch`: closes the notifications sent from a terminal outside
# tmux once its window gains focus. Inside tmux, tmux's own hooks do that
# (dot-tmux.conf); outside it only Hyprland sees the focus change.
#
# A user service rather than an exec in autostart.lua, so a dropped event
# socket is restarted and the reason lands in the journal. The user manager
# has HYPRLAND_INSTANCE_SIGNATURE from autostart.lua's
# dbus-update-activation-environment.
{ pkgs, ... }:
let
  shell-notify = pkgs.callPackage ../../pkgs/shell-notify.nix { };
in
{
  systemd.user.services.shell-notify-watch = {
    Unit = {
      Description = "Close terminal notifications when their window gains focus";
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${shell-notify}/bin/shell-notify watch";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
