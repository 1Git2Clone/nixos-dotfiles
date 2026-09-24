# overrideDevices and overrideFolders stay false. Their default is true, which
# makes the lists below the whole truth and deletes anything added from the
# GUI on every activation. With them off the updater POSTs rather than PUTs:
# declarations are added and updated, GUI additions are left alone.
#
# Tailnet only: modules/tailscale.nix trusts tailscale0 and the input chain
# has no rule for 8384 or 22000, so nothing else reaches either. Same
# arrangement as the VPS's copy of this module.
{ config, lib, ... }:
let
  inherit (config.users.users.hutao) home;
  inherit (config.networking) hostName;
  root = "${home}/syncthing";

  # Public values: a device ID is the SHA-256 of that node's TLS certificate,
  # which is the string you paste into a peer to pair. It could not be hidden
  # anyway -- settings.devices.*.id is a plain str read at build time, and the
  # module has no idFile.
  #
  # A host missing here still pairs from the GUI, but the folder below is not
  # shared with it, so it offers the folder back on every connection.
  peers = {
    hutao-desktop = "2UE2BQ2-AGJLUEY-IXUSURZ-INSQRGF-PMWKNZD-VSVZ4JJ-6XWGTWL-C6XQMQ5";
    hutao-laptop = "IARCZU3-3HVMAAR-TDJA2LI-3HFWJCU-HKH2E7F-X24WDVO-7LCZHOZ-XDYZRA3";
    vps = "Z3BRNQT-T2HJQY2-XNDOXNO-FJLIJR5-S7U6UUA-Z4CYGYS-UVF5EYH-DZMFWQM";

    # A phone, so it never imports this module and never appears as hostName.
    # The key is its MagicDNS name, which is what the address below resolves.
    xiaomi-12 = "VIQT7TM-224ZM45-JJIT5T6-I7DKFSZ-EY3BG5Y-RNKYJAH-UBW5DJ2-WZE7RQK";
  };

  # Pairing is mutual, so each machine importing this declares the others and
  # no first connection has to be accepted by hand.
  others = lib.filterAttrs (n: _: n != hostName) peers;
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

    settings.devices = lib.mapAttrs (name: id: {
      inherit id;
      # MagicDNS first: 22000 is only open on tailscale0, so a globally
      # discovered address reaches nothing. "dynamic" stays as the fallback
      # for when MagicDNS is not answering.
      addresses = [
        "tcp://${name}:22000"
        "dynamic"
      ];
    }) others;

    # The id has to match the VPS's existing folder exactly, or this is a
    # different folder that merely shares a path.
    settings.folders.${root} = {
      id = "hazch-yurju";
      label = "Main (~/syncthing)";
      devices = builtins.attrNames others;

      versioning = {
        type = "simple";
        params.keep = "10";
      };
    };
  };

  # The module declares dataDir but never creates it.
  systemd.tmpfiles.rules = [ "d ${root} 0700 hutao users -" ];
}
