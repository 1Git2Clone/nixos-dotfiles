# nixos-generate-config --no-filesystems --show-hardware-config, committed so
# the host evaluates from a fresh clone. disko owns fileSystems.*.
#
# The module list is the generator's, kept as detected. ahci and sd_mod are
# the HDD this host also has; usbhid and usb_storage are redundant, since
# includeDefaultModules supplies them either way, but removing them would make
# the next regeneration a diff for no gain.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
