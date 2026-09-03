# Installer ISO driveable over ssh and watchable on a serial console. The
# stock one has no way in over the network: empty passwords, which sshd
# refuses.
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

  # zstd -3 over xz: a third of the build time, ~200MB more, booted once.
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
}
