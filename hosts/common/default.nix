# ==============================================================================
# What every real machine shares
# ==============================================================================
# Imported by hosts/hutao-laptop and, when it lands, hosts/hutao-desktop. If a
# setting is here, the two machines cannot drift apart on it; if it is in a
# host directory, it is genuinely a property of that hardware.
#
# Deliberately NOT imported by hosts/vm: everything below either needs real
# firmware (Limine, EFI variables) or a real install (sops, immutable users).
# The VM covers the desktop layer instead — see hosts/vm/default.nix.
#
# The line between this file and a host file:
#
#   here          bootloader, kernel, graphics stack, secrets, users
#   host file     disko layout, hardware-configuration.nix, GPU quirks,
#                 stateVersion
#
# stateVersion in particular stays per-host. It records which stateful-data
# migrations a machine has already had applied, so a desktop installed a year
# from now gets its own value and must not inherit the laptop's.
{ pkgs, ... }:
{
  imports = [
    ../../modules/sops.nix
    ../../modules/users.nix
  ];

  boot = {
    loader = {
      # Limine on both machines. The ESP is unencrypted and holds kernels +
      # initrd; the initrd unlocks LUKS before mounting root.
      limine = {
        enable = true;
        efiSupport = true;
        # Cap retained boot entries — /nix/store grows with every generation
        # kept, and the ESP holds a kernel + initrd for each.
        maxGenerations = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };

    # scx needs 6.12+. Unstable's default already qualifies, but pinning latest
    # means a channel bump cannot silently drop below it and disable
    # services.scx on both machines at once.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
