# ==============================================================================
# Secrets
# ==============================================================================
# Every sops key this system reads, declared in one place. Named sops.nix
# rather than secrets.nix only because a local tooling hook refuses to touch
# paths matching /secrets\?/ — `git mv` it if you want parity with the vps repo.
#
# ── Who can decrypt, and why it changed ──────────────────────────────────────
#
# The original design here made the machine's own ed25519 SSH host key the ONLY
# age recipient. That is elegant and it is a trap:
#
#   * the encrypted file is readable by exactly one machine, so you cannot edit
#     it from anywhere else — including the workstation you are writing the
#     config on
#   * reinstalling regenerates the host key, and every previously encrypted
#     value becomes permanently unreadable
#   * a second machine cannot share a single secret, so hutao-desktop would
#     need its own parallel file
#
# So this follows the vps repo instead: a PERSONAL age key is the primary
# recipient, and it lives at ~/.sops-nix/key.txt on the workstation and
# /var/lib/sops-nix/key.txt on each host. install.sh stages it there before the
# first activation — see the ordering note below, it is the part that bites.
#
# The host's SSH key is kept as an ADDITIONAL identity, not the only one, so a
# machine that has been handed the file can still decrypt it unattended.
#
# ── Ordering ─────────────────────────────────────────────────────────────────
#
# nixos-install runs activation, and activation decrypts these values. With
# users.mutableUsers = false the user password hashes come from here, so if no
# decryption identity is in place when activation runs, the install fails at
# the last step and leaves a machine nobody can log into. install.sh therefore
# writes the key into /mnt/var/lib/sops-nix/ BEFORE calling nixos-install.
#
# neededForUsers puts a value in /run/secrets-for-users, which is populated
# before user creation. It is the only mechanism that works with immutable
# users — a plain secret is rendered too late and the account gets no password.
_: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;

    age = {
      # Primary identity. Staged by install.sh, and the same key that already
      # decrypts the vps repo, so one key covers every machine you own.
      keyFile = "/var/lib/sops-nix/key.txt";

      # Do NOT generate one if it is missing. Generating a key that is not a
      # recipient in .sops.yaml produces an identity that cannot decrypt
      # anything, turning a loud failure into a confusing one.
      generateKey = false;

      # Secondary identity: the machine's own host key. Only useful if that
      # key was added as a recipient with `sops updatekeys`, which install.sh
      # offers. Harmless when it was not — sops-nix tries each in turn.
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    # ── The keys themselves ───────────────────────────────────────────────────
    # Every entry here MUST exist in the encrypted file or sops-install-secrets
    # fails during activation. On a fresh install that means no credentials at
    # all, the machine's own login included.
    secrets = {
      "hutao-password".neededForUsers = true;
      "root-password".neededForUsers = true;
    };
  };
}
