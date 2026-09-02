# Immutable accounts; hashes come from modules/sops.nix.
#
# root gets one too — the emergency door if the display manager or the hutao
# account breaks.
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
