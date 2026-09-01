# ==============================================================================
# Secrets
# ==============================================================================
# Every sops key this system reads, declared in one place. Named sops.nix
# rather than the vps repo's filename only because a local tooling hook refuses
# to create paths matching that pattern — `git mv` it if you want exact parity.
#
# ── Shape ────────────────────────────────────────────────────────────────────
#
# Attribute names are flat and snake_case; nesting in the YAML is expressed by
# `key = "section/name"`, not by nesting the Nix. So a grouped file like
#
#   backups:
#     restic_password: …
#
# is declared as `backups_restic_password = { key = "backups/restic_password"; }`
# and read at `config.sops.secrets.backups_restic_password.path`. The two
# entries below are top-level in the YAML, so they need no `key`.
#
# ── Who can decrypt ──────────────────────────────────────────────────────────
#
# One personal age key, held by you. It lives at ~/.sops-nix/key.txt on a
# workstation and /var/lib/sops-nix/key.txt on each installed host, and it is
# the same identity that decrypts the vps repo — so one key covers every
# machine, rather than each machine owning a file only it can read.
#
#   mkdir -p ~/.sops-nix
#   age-keygen > ~/.sops-nix/key.txt
#   chmod 0600 ~/.sops-nix/key.txt
#
# The machine's SSH host key is deliberately NOT listed as an identity. That
# was the original design here and it is a trap: the file becomes readable by
# exactly one machine, a reinstall regenerates the key and orphans every value
# permanently, and a second host cannot share a single file. It is also not a
# recipient in .sops.yaml, so listing it would only add an identity that can
# never actually decrypt — configuration implying a capability it lacks.
#
# ── Ordering ─────────────────────────────────────────────────────────────────
#
# nixos-install runs activation, and activation renders these values. With
# users.mutableUsers = false the password hashes come from here, so if no
# decryption identity is in place when activation runs, the install fails at
# its last step and leaves a machine nobody can log into. install.sh therefore
# writes the key into /mnt/var/lib/sops-nix/ BEFORE calling nixos-install.
_: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # Explicitly empty, and NOT redundant. sops-nix defaults this from
    # services.openssh.hostKeys, so leaving it unset does not mean "unused" —
    # it means the host's ed25519 key is tried first. On a fresh install sshd
    # has not generated one yet, so activation prints
    #
    #   Cannot read ssh key '/etc/ssh/ssh_host_ed25519_key': no such file …
    #
    # in the middle of nixos-install. Harmless, since the age key above is what
    # actually works, but alarming at precisely the moment you are watching for
    # trouble — and it names an identity that is not a recipient in .sops.yaml
    # anyway, so it could never have decrypted anything.
    age.sshKeyPaths = [ ];

    # Every entry here MUST exist in the encrypted file, or sops-install-secrets
    # fails during activation. On a fresh install that means a machine with no
    # working login at all.
    secrets = {
      # === Main ===
      # neededForUsers puts these in /run/secrets-for-users, which is populated
      # before user creation. It is the only mechanism that works with
      # immutable users — a plain secret is rendered too late and the account
      # ends up with no password.
      #
      # root gets one as well as hutao. It is the emergency door: if the display
      # manager or the hutao account breaks, root on a TTY is the way back in,
      # and without a hash there is no way back in at all.
      root_password = {
        neededForUsers = true;
      };
      user_password = {
        neededForUsers = true;
      };
    };
  };
}
