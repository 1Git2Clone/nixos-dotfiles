# Every sops key, in one place. Nesting lives in `key = "section/name"`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The whole provider story: the key under `llm:` in secrets.yaml, mapped to
  # the env var opencode and every SDK already look for. One line here
  # plus one in secrets.yaml is one more provider — a key listed but absent
  # from secrets.yaml fails activation, so only add a line once you hold it.
  llmKeys = {
    openrouter = "OPENROUTER_API_KEY";
    opencode = "OPENCODE_API_KEY";
    vercel = "AI_GATEWAY_API_KEY";
    minimax = "MINIMAX_API_KEY";
  };

  # Private-flake tokens, by host. Forgejo is the source of truth and GitHub the
  # mirror, so either can be a flake input URL. Adding a host is one entry here
  # plus one key under `nix:` in secrets.yaml.
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

  # Nix hands `git+https://` inputs to git, so what authenticates them is a
  # *git* credential helper — not nix.settings.netrc-file, which only covers
  # the downloads Nix makes itself.
  #
  # `store` is the helper git ships: it reads a file, so it needs no daemon, no
  # keyring and no session, which is exactly what root has. One section per
  # host, and deliberately NOT in /etc/gitconfig: git consults system, then
  # global, then local helpers and stops at the first that answers, so a
  # system-wide store helper would answer for hutao too and never reach the
  # GCM/keyring path their interactive git is set up for.
  rootGitconfig = pkgs.writeText "root-gitconfig" (
    lib.concatMapStringsSep "\n" (token: ''
      [credential "https://${token.host}"]
        helper = store --file=${config.sops.templates."git-credentials".path}
    '') (lib.attrValues nixTokens)
  );
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

      # Plaintext too: `sunshine --creds` salts and hashes it itself. owner
      # because Sunshine is a user service.
      sunshine_password = {
        owner = "hutao";
      };

      # luks_passphrase is in secrets.yaml but deliberately not declared:
      # it would render the disk's own passphrase to /run/secrets on every
      # boot of the machine it unlocks. Only install.sh needs it.
    }
    # Default root:root 0400 is right: nothing reads these directly, only the
    # templates below, and those are what carry the owner.
    // lib.mapAttrs' (name: _: lib.nameValuePair "llm/${name}" { }) llmKeys
    // lib.mapAttrs' (name: _: lib.nameValuePair "nix/${name}" { }) nixTokens;

    # One env file out of the section above, for the `set -a` in
    # dot-profile.d/environment.sh that hands the keys to every shell-launched
    # tool. owner, because it reads it as hutao.
    templates."llm.env" = {
      owner = "hutao";
      content = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: var: "${var}=${config.sops.placeholder."llm/${name}"}") llmKeys
      );
    };

    # The Sunshine web UI login as a curl --netrc-file, so the disconnect
    # watcher in hosts/hutao-desktop never puts the password in argv.
    templates."sunshine-netrc" = {
      owner = "hutao";
      content = "machine localhost login hutao password ${config.sops.placeholder.sunshine_password}";
    };

    # git's credential-store format: one line per host. Rendered to /run at
    # activation and root-only, so the token stays sops-only — never in the
    # store, never world-readable. sops-nix renders this one 0600 rather than
    # the 0400 requested in `mode`; only root being able to read it is the part
    # that matters. Root reads it because root reads any file; no group
    # membership is involved, whatever gid a sudo'd process carries.
    templates."git-credentials" = {
      owner = "root";
      mode = "0400";
      content = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: token: "https://${token.login}:${config.sops.placeholder."nix/${name}"}@${token.host}"
        ) nixTokens
      );
    };
  };

  # `sudo nixos-rebuild` evaluates the flake as root, which has no keyring and
  # no git config of its own, so every private input dies with "could not read
  # Username". This is the config root does read. Kept in this module rather
  # than modules/system.nix because the installer image does not import sops,
  # and config.sops is undefined there.
  systemd.tmpfiles.rules = [ "L+ /root/.gitconfig - - - - ${rootGitconfig}" ];
}
