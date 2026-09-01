# Immutable users, passwords from sops.
#
# The bootstrap ordering that makes this work at all:
#   1. install.sh generates the machine's ed25519 host key BEFORE install
#   2. ssh-to-age converts its pubkey into an age recipient in .sops.yaml
#   3. the private key is placed at /mnt/etc/ssh/ssh_host_ed25519_key
#   4. sops.age.sshKeyPaths points at it, so first-boot activation can decrypt
#   5. neededForUsers lands the hashes in /run/secrets-for-users, which is
#      populated *before* user creation
#
# Break any link and you get a machine you cannot log into. That is why root
# also gets a hash: it is the emergency door.
{ config, pkgs, ... }:
{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "hutao-password".neededForUsers = true;
      "root-password".neededForUsers = true;
    };
  };

  users.mutableUsers = false;

  users.users.hutao = {
    isNormalUser = true;
    description = "hutao";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
    hashedPasswordFile = config.sops.secrets."hutao-password".path;
    shell = pkgs.zsh;
  };

  users.users.root.hashedPasswordFile = config.sops.secrets."root-password".path;

  # Required whenever a user's shell is zsh — without it the shell is not
  # registered in /etc/shells and login fails.
  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = true;
}
