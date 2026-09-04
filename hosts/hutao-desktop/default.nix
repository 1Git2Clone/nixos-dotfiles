# Ryzen 5 3600X, RX 5700 XT (Navi 10), 16GB, 512GB NVMe + 2TB NTFS HDD.
# This machine only; anything shared lives in hosts/common or modules/.
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

  # Left for removable NTFS media; the HDD itself is ext4 now.
  boot.supportedFilesystems.ntfs = true;

  # Formatted by hand, once -- deliberately not in modules/disk-layout.nix, so
  # a reinstall touches the NVMe alone and cannot wipe this. Only the unlock
  # and the mount are declared.
  #
  # In the initrd rather than stage 2 because boot.initrd.systemd is on:
  # systemd-cryptsetup retries the password it already cached for cryptroot,
  # so one prompt opens both. The cost is that a missing disk waits out a
  # 90s timeout before boot carries on.
  boot.initrd.luks.devices.crypthdd = {
    device = "${disk.hddDevice}-part1";
    allowDiscards = false;
    crypttabExtraOpts = [ "x-initrd.attach" ];
  };

  fileSystems.${disk.hddMount} = {
    device = "/dev/mapper/crypthdd";
    fsType = "ext4";
    # nofail, so a disk that is missing or will not open costs a failed mount
    # unit rather than a boot.
    options = [ "nofail" ];
  };

  environment.systemPackages = [ pkgs.teams-for-linux ];

  # There is no Outlook for Linux; evolution speaks EWS to Exchange Online.
  # The option rather than the two packages: dbus activates the backend's
  # daemons, and only evolutionWithPlugins' join lets them find the plugin.
  programs.evolution = {
    enable = true;
    plugins = [ pkgs.evolution-ews ];
  };

  # Never change after install.
  system.stateVersion = "26.05";
}
