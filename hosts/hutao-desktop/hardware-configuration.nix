# Hand-written from the running machine rather than generated, because it was
# still on Arch when this was added. Regenerate on the installed host with
#   nixos-generate-config --no-filesystems --show-hardware-config
# and replace this file if anything looks off. disko owns fileSystems.*.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;

}
