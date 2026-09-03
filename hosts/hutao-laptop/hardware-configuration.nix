# Generated on the machine with
#   nixos-generate-config --no-filesystems --show-hardware-config
# and committed, so the host evaluates from a fresh clone. disko owns
# fileSystems.*; regenerate and replace this file if hardware changes.
#
# The short module list is fine: boot.initrd.includeDefaultModules stays true,
# which is what puts usbhid/hid_generic/atkbd/i8042 in the initrd — i.e. what
# lets you type the LUKS passphrase.
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
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
