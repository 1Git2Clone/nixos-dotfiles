# Every sops key, in one place. Nesting lives in `key = "section/name"`.
{ config, lib, ... }:
let
  # The whole provider story: the key under `llm:` in secrets.yaml, mapped to
  # the env var opencode, hermes and every SDK already look for. One line here
  # plus one in secrets.yaml is one more provider — a key listed but absent
  # from secrets.yaml fails activation, so only add a line once you hold it.
  llmKeys = {
    openrouter = "OPENROUTER_API_KEY";
    opencode = "OPENCODE_API_KEY";
  };

  # Private-flake tokens, by host, for the netrc template below. Forgejo is the
  # source of truth and GitHub the mirror, so either can be a flake input URL.
  # Adding a host is one entry here plus one key under `nix:` in secrets.yaml.
  nixTokens = {
    forgejo_token = {
      host = "git.hu-tao.dev";
      login = "hutao";
    };
    github_token = {
      host = "github.com";
      login = "1Git2Clone";
    };
  };
in
{
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

      # Plaintext, not a hash: syncthing-init bcrypts it at activation. owner
      # because that unit runs as hutao.
      syncthing_gui_password = {
        owner = "hutao";
      };

      # luks_passphrase is in secrets.yaml but deliberately not declared:
      # it would render the disk's own passphrase to /run/secrets on every
      # boot of the machine it unlocks. Only install.sh needs it.
    }
    # Default root:root 0400 is right: nothing reads these directly, only the
    # template below, and that is what carries the owner.
    // lib.mapAttrs' (name: _: lib.nameValuePair "llm/${name}" { }) llmKeys
    // lib.mapAttrs' (name: _: lib.nameValuePair "nix/${name}" { }) nixTokens;

    # One env file out of the section above, because an env file is the shape
    # both consumers take: hermes' environmentFiles, and the `set -a` in
    # dot-profile.d/environment.sh that hands the keys to every shell-launched
    # tool. owner, because both read it as hutao.
    templates."llm.env" = {
      owner = "hutao";
      content = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: var: "${var}=${config.sops.placeholder."llm/${name}"}") llmKeys
      );
    };

    # Credentials for private flake inputs over HTTPS, keyed by host so either
    # Forgejo or GitHub can be the input URL.
    #
    # `git+https://` consults this file via nix.settings.netrc-file below. The
    # `github:` shorthand would instead need nix.settings.access-tokens, which
    # writes the token into the world-readable store -- so use `git+https://`
    # for private repos and let the tokens stay here.
    #
    # Not 0400 root-only like the secrets above: the daemon and sudo fetch as
    # root, but a plain `nix flake update` runs as hutao and would fail on a
    # root-only file. 0440 plus hutao's primary group covers both.
    templates."nix-netrc" = {
      owner = "root";
      group = "users";
      mode = "0440";
      content = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: host:
          "machine ${host.host} login ${host.login} password ${config.sops.placeholder."nix/${name}"}"
        ) nixTokens
      );
    };
  };

  # The consumer side of the template above. Kept in this module rather than
  # modules/system.nix because the installer image does not import sops, and
  # config.sops is undefined there.
  nix.settings.netrc-file = config.sops.templates."nix-netrc".path;
}
