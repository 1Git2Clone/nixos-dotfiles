# Every sops key, in one place. Nesting lives in `key = "section/name"`.
_: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # sops-nix otherwise defaults this from services.openssh.hostKeys — a key
    # that is not a recipient and does not exist yet at activation.
    age.sshKeyPaths = [ ];

    secrets = {
      # neededForUsers renders to /run/secrets-for-users, the only stage early
      # enough for mutableUsers = false.
      root_password = {
        neededForUsers = true;
      };
      user_password = {
        neededForUsers = true;
      };

      tailscale_authkey = { };

      # An .env-shaped blob (KEY=value per line), not a single value: hermes
      # reads it with load_hermes_dotenv() and the provider keys travel
      # together. owner, because home-manager's activation runs as hutao and
      # the default 0400 root:root is unreadable to it — the sops-nix default
      # suits a systemd unit's LoadCredential, not a user-level module.
      "hermes/env" = {
        owner = "hutao";
      };

      # luks_passphrase is in secrets.yaml but deliberately not declared:
      # it would render the disk's own passphrase to /run/secrets on every
      # boot of the machine it unlocks. Only install.sh needs it.
    };
  };
}
