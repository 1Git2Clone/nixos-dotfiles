# Peers and folders are added from the GUI, so overrideDevices and
# overrideFolders have to stay false: their default is true, which deletes
# everything not declared here on every activation.
#
# No firewall rules — modules/tailscale.nix already trusts tailscale0, which
# is how the two machines reach each other. openDefaultPorts = true adds LAN
# sync (22000, and 21027 for local discovery).
{ config, ... }:
let
  inherit (config.users.users.hutao) home;
  root = "${home}/syncthing";
in
{
  services.syncthing = {
    enable = true;
    user = "hutao";
    group = "users";

    dataDir = root;
    # Not left to default under dataDir, which would put the device key and
    # database inside the tree being synced.
    configDir = "${home}/.config/syncthing";

    overrideDevices = false;
    overrideFolders = false;

    # What "Add Folder" prefills in the GUI, reachable at
    # http://127.0.0.1:8384 on each machine.
    settings.defaults.folder.path = root;
  };

  # The module declares dataDir but never creates it.
  systemd.tmpfiles.rules = [ "d ${root} 0700 hutao users -" ];
}
