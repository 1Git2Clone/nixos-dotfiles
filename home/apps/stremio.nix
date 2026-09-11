# The web app talks to a local streaming server on 11470/12470, and nothing
# starts it: the package ships only a binary and a .desktop, and nixpkgs has
# no services.stremio-service. Without this the web app just says
# "Streaming server is not available".
#
# A user service for a user's media player, so home-manager owns it -- it
# needs no root, and nothing but this session should be starting it.
{ pkgs, ... }:
{
  systemd.user.services.stremio-service = {
    Unit = {
      Description = "Stremio streaming server";
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.stremio-service}/bin/stremio-service";
      Restart = "on-failure";
    };
  };
}
