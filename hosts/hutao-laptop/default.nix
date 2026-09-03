# Lenovo IdeaPad 1 15AMN7 — Ryzen 3 7320U, Radeon 610M, 8GB, NVMe.
_: {
  imports = [
    ../common
    (import ../../modules/disk-layout.nix (import ./disk.nix))
    ./hardware-configuration.nix
  ];

  networking.hostName = "hutao-laptop";

  # nixpkgs' amdgpu module puts amdgpu in the initrd because videoDrivers names
  # it. Early KMS then finishes its mode set a few seconds into the passphrase
  # prompt and resets the console underneath it: the prompt text is never
  # redrawn and the new console starts below the leftover "Starting
  # Cryptography Setup" lines. Stage 2 loads it after the unlock instead.
  hardware.amdgpu.initrd.enable = false;
  boot.kernelModules = [ "amdgpu" ];

  # Never change after install.
  system.stateVersion = "26.05";
}
