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

      # An .env-shaped blob, read by home-manager's activation as hutao — the
      # default 0400 root:root is unreadable to it.
      "hermes/env" = {
        owner = "hutao";
      };

      # Plaintext, not a hash: syncthing-init bcrypts it at activation. owner
      # because that unit runs as hutao.
      syncthing_gui_password = {
        owner = "hutao";
      };

      # luks_passphrase is in secrets.yaml but deliberately not declared:
      # it would render the disk's own passphrase to /run/secrets on every
      # boot of the machine it unlocks. Only install.sh needs it.
    };
  };
}
