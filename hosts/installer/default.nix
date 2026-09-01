# A NixOS installer ISO that can be driven over SSH and watched on a serial
# console — the harness `install.sh` is tested with.
#
# The stock minimal ISO leaves `nixos` and `root` with *empty* passwords, and
# sshd refuses empty-password logins. That is fine when you are sitting at the
# machine and useless when you are not: there is no way in over the network
# until someone types `passwd` at the physical console.
#
# This image fixes exactly that, and nothing else:
#   - authorized keys from ../../vm/authorized_keys
#   - kernel + getty on ttyS0, so a VM harness can read the whole boot
#   - the tools install.sh checks for, already on PATH
#
# Build:  nix build .#installer-iso
# Real hardware: add your own key to vm/authorized_keys FIRST, then
#   sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  # Kernel messages and a login prompt on the serial port. tty0 is listed too
  # so the physical screen keeps working — the last console= wins for
  # /dev/console, and a getty is spawned on each.
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "prohibit-password";
  };

  # Both accounts: `nixos` is the autologin user, `root` is what install.sh
  # needs (it refuses to run unprivileged).
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../vm/authorized_keys ];
  users.users.nixos.openssh.authorizedKeys.keyFiles = [ ../../vm/authorized_keys ];

  # Everything install.sh preflights for, so it does not have to be wrapped in
  # `nix-shell -p ...` on the target.
  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
    mkpasswd
    git
    jq
    rsync
  ];

  # The installer needs the same flake inputs the target does; without this it
  # re-resolves them against the GitHub API and burns the 60/h anonymous quota.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.hostName = lib.mkForce "nixos-installer";

  # zstd -3 over the default xz: roughly a third of the build time for an
  # image that is only ever booted once. Costs ~200MB of ISO size.
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
}
