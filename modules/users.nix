# Immutable accounts; hashes from modules/sops.nix. root gets one as the
# emergency door.
{ config, pkgs, ... }:
{
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
    hashedPasswordFile = config.sops.secrets.user_password.path;
    shell = pkgs.zsh;
  };

  users.users.root.hashedPasswordFile = config.sops.secrets.root_password.path;

  # Without this zsh is not in /etc/shells and login fails.
  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = true;
}
