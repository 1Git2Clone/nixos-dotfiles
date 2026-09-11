# The web app talks to a local streaming server on 11470/12470, and nothing
# starts it: the package ships only a binary and a .desktop, and nixpkgs has
# no services.stremio-service. Without this the web app just says
# "Streaming server is not available".
{ pkgs, ... }:
{
  systemd.user.services.stremio-service = {
    description = "Stremio streaming server";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.stremio-service}/bin/stremio-service";
      Restart = "on-failure";
    };
  };
}
