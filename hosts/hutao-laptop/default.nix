# Lenovo IdeaPad 1 15AMN7 — Ryzen 3 7320U, Radeon 610M, 8GB, NVMe.
_: {
  imports = [
    ../common
    (import ../../modules/disk-layout.nix (import ./disk.nix))
    ./hardware-configuration.nix
  ];

  networking.hostName = "hutao-laptop";

  # videoDrivers otherwise puts amdgpu in the initrd, and early KMS resets the
  # console mid-passphrase-prompt without redrawing it. Stage 2 loads it after
  # the unlock instead.
  hardware.amdgpu.initrd.enable = false;
  boot.kernelModules = [ "amdgpu" ];

  # Never change after install.
  system.stateVersion = "26.05";
}
