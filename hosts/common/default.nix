# Shared by every real machine. hosts/vm deliberately does not import this:
# Limine, sops and immutable users all need real firmware or a real install.
# stateVersion stays per-host.
{ pkgs, ... }:
{
  imports = [
    ../../modules/sops.nix
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
    # services.scx needs 6.12+; pinned so a channel bump cannot drop below it.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
