# Installer ISO that can be driven over ssh and watched on a serial console.
#
# The stock ISO leaves nixos and root with empty passwords and sshd refuses
# empty-password logins, so there is no way in over the network until someone
# types passwd at the physical console.
#
#   nix build .#installer-iso
#   sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
#
# Add your own key to vm/authorized_keys before writing it to a USB stick.
{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../vm/authorized_keys ];
  users.users.nixos.openssh.authorizedKeys.keyFiles = [ ../../vm/authorized_keys ];

  # What install.sh preflights for.
  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
    mkpasswd
    git
    jq
    rsync
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.hostName = lib.mkForce "nixos-installer";

  # zstd -3 over the default xz: a third of the build time for an image booted
  # once, at ~200MB more size.
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
}
