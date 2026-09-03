# Lenovo IdeaPad 1 15AMN7 — Ryzen 3 7320U, Radeon 610M, 8GB, NVMe.
_: {
  imports = [
    ../common
    (import ../../modules/disk-layout.nix (import ./disk.nix))
    ./hardware-configuration.nix
  ];

  networking.hostName = "hutao-laptop";

  # Early KMS: framebuffer up before the LUKS prompt.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Never change after install.
  system.stateVersion = "26.05";
}
