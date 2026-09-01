# ==============================================================================
# Users
# ==============================================================================
# Immutable accounts whose passwords come from sops. The sops wiring itself —
# which file, which identities, which keys — lives in modules/sops.nix; this
# file only consumes the rendered paths.
#
# `mutableUsers = false` means passwd(1) cannot change anything: the hashes in
# the encrypted file are the whole truth. That is the point, and it is also why
# root gets a hash too. If the display manager breaks or the hutao account is
# somehow unusable, root on a TTY is the emergency door — without it a bad
# graphical session is a reinstall.
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
    hashedPasswordFile = config.sops.secrets."hutao-password".path;
    shell = pkgs.zsh;
  };

  users.users.root.hashedPasswordFile = config.sops.secrets."root-password".path;

  # Required whenever a user's shell is zsh — without it the shell is not
  # registered in /etc/shells and login fails.
  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = true;
}
