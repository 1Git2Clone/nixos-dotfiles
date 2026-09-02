# Every sops key, in one place. Named sops.nix because a local tooling hook
# refuses to create paths matching the vps repo's filename.
#
# Flat snake_case attrs; nesting lives in `key = "section/name"`, e.g.
# `backups_restic_password = { key = "backups/restic_password"; }`.
#
# One personal age key decrypts everything, on every machine:
#   ~/.sops-nix/key.txt          workstation
#   /var/lib/sops-nix/key.txt    installed host, put there by install.sh
#
# install.sh must stage it BEFORE nixos-install: activation renders these, and
# with mutableUsers = false a missing key means a machine nobody can log into.
_: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # Not redundant. sops-nix defaults this from services.openssh.hostKeys, so
    # leaving it unset makes activation try a host key that does not exist yet
    # and print "Cannot read ssh key ..." mid-install. It is not a recipient in
    # .sops.yaml either, so it could never decrypt anything.
    age.sshKeyPaths = [ ];

    # Missing entries fail activation. neededForUsers renders to
    # /run/secrets-for-users, the only thing early enough for immutable users.
    secrets = {
      # === Main ===
      root_password = {
        neededForUsers = true;
      };
      user_password = {
        neededForUsers = true;
      };
    };
  };
}
