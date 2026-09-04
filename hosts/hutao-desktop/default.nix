# Ryzen 5 3600X, RX 5700 XT (Navi 10), 16GB, 512GB NVMe + 2TB NTFS HDD.
# Hardware plus whatever belongs to this machine alone; anything both real
# machines want goes in hosts/common or modules/.
let
  disk = import ./disk.nix;
in
{ pkgs, ... }:
{
  imports = [
    ../common
    (import ../../modules/disk-layout.nix disk)
    ./hardware-configuration.nix
  ];

  networking.hostName = "hutao-desktop";

  boot.initrd.kernelModules = [ "amdgpu" ];

  # In-kernel ntfs3 driver, not the FUSE one. `force` mounts a volume Windows
  # left dirty (fast startup / hibernation) instead of refusing.
  boot.supportedFilesystems.ntfs = true;
  fileSystems.${disk.hddMount} = {
    device = "/dev/disk/by-uuid/${disk.hddUuid}";
    fsType = "ntfs3";
    options = [
      "uid=1000"
      "gid=1000"
      "nofail"
      "force"
    ];
  };

  # Desk work, this machine only — the laptop gets neither. A host module is
  # all it takes: environment.systemPackages is a list option, so this merges
  # with the one modules/desktop.nix sets rather than replacing it.
  environment.systemPackages = [ pkgs.teams-for-linux ];

  # There is no Outlook for Linux and no nixpkgs wrapper for one, so this is
  # the stand-in: evolution speaks EWS to Exchange Online natively, giving
  # mail, calendar and contacts off the same M365 login.
  #
  # The option and not a systemPackages pair, because the backend is loaded by
  # evolution-data-server's dbus-activated daemons rather than by evolution.
  # It builds evolutionWithPlugins, which symlink-joins the three, sets
  # EDS_EXTRA_PREFIXES so the daemons find the EWS backend, and rewrites the
  # dbus and systemd unit files to point into the join. Listing the two
  # packages instead would activate the unjoined daemons, which never see the
  # plugin.
  programs.evolution = {
    enable = true;
    plugins = [ pkgs.evolution-ews ];
  };

  # Never change after install.
  system.stateVersion = "26.05";
}
