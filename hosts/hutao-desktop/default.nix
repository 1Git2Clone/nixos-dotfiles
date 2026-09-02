# Ryzen 5 3600X, RX 5700 XT (Navi 10), 16GB, 512GB NVMe + 2TB NTFS HDD.
# Hardware-specific only; everything else is in hosts/common.
let
  disk = import ./disk.nix;
in
_: {
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

  # Never change after install.
  system.stateVersion = "26.05";
}
