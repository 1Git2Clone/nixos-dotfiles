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

  # The HDD is LUKS + ext4 now and disko owns its fileSystems entry. This is
  # only left for removable NTFS media.
  boot.supportedFilesystems.ntfs = true;

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
