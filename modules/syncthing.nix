# Peers and folders are added from the GUI, so overrideDevices and
# overrideFolders have to stay false: their default is true, which deletes
# everything not declared here on every activation.
#
# Tailnet only: modules/tailscale.nix trusts tailscale0 and the input chain
# has no rule for 8384 or 22000, so nothing else reaches either. Same
# arrangement as the VPS's copy of this module.
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

    # 0.0.0.0, restricted by the firewall and not by the bind address, so the
    # GUI is reachable from the other machines over the tailnet.
    guiAddress = "0.0.0.0:8384";

    # The tailnet authenticates a peer, not a person: without this, any node
    # on it has unauthenticated read/write over every synced file, and
    # syncthing says so on startup. Plaintext file -- syncthing-init bcrypts
    # it and PATCHes /rest/config/gui.
    settings.gui.user = "hutao";
    guiPasswordFile = config.sops.secrets.syncthing_gui_password.path;

    # What "Add Folder" prefills in the GUI.
    settings.defaults.folder.path = root;
  };

  # The module declares dataDir but never creates it.
  systemd.tmpfiles.rules = [ "d ${root} 0700 hutao users -" ];
}
