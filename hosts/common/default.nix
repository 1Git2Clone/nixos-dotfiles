# Every real machine. hutao-vm does not import this: Limine, sops and
# immutable users all need a real install. stateVersion stays per-host.
{ pkgs, ... }:
{
  imports = [
    ../../modules/sops.nix
    ../../modules/tailscale.nix
    ../../modules/users.nix
  ];

  boot = {
    loader = {
      limine = {
        enable = true;
        efiSupport = true;
        maxGenerations = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    # services.scx needs 6.12+.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # Leave this false and nixos-hardware's updateMicrocode mkDefault conflicts
  # with nixos-generate-config's.
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
