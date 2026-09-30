# Secrets

One personal age key: `~/.sops-nix/key.txt` on a workstation and
`/var/lib/sops-nix/key.txt` on each host. The recipients are in `.sops.yaml`,
committed on purpose because they are public keys. The encrypted values are in
`secrets/secrets.yaml`, also committed, which is the point of sops.

```bash
SOPS_AGE_KEY_FILE=~/.sops-nix/key.txt nix develop -c sops secrets/secrets.yaml
```

`secrets/secrets.example.yaml` shows the decrypted shape, with a comment per
key. `modules/sops.nix` declares every key and is the one place to add one.

## The keys

| Key                                     | What                                        | Consumer                                  |
| --------------------------------------- | ------------------------------------------- | ----------------------------------------- |
| `root_password`                         | crypt(3) hash, `mkpasswd -m yescrypt`       | `modules/users.nix`                       |
| `user_password`                         | crypt(3) hash, `mkpasswd -m yescrypt`       | `modules/users.nix`                       |
| `luks_passphrase`                       | the passphrase itself, in the clear         | `install.sh` only, never declared         |
| `tailscale_authkey`                     | reusable, pre-authorized, **not** ephemeral | `modules/tailscale.nix`                   |
| `syncthing_gui_password`                | plaintext; syncthing-init bcrypts it        | `modules/syncthing.nix`                   |
| `sunshine_password`                     | plaintext; `sunshine --creds` hashes it     | `hosts/hutao-desktop`                     |
| `llm.*` (see `llmKeys`)                 | provider API keys                           | rendered into one `llm.env`               |
| `nix.forgejo_token`, `nix.github_token` | read tokens for private flake inputs        | rendered into root's git credential store |

**Every declared key must exist**, on every host, before anything builds.
sops-nix checks the manifest at build time, and a missing key is a failed
build that names it:

```text
secret sunshine_password in …-secrets.yaml is not valid: the key 'sunshine_password' cannot be found
```

`install.sh` reads the same list out of the flake and checks every key before
it touches a disk, so an install stops at the preflight instead of failing
inside `nixos-install` on a wiped disk.

## Values with quirks

- **YAML quoting.** A value starting with `*`, `&`, `!`, `%`, `@` or a backtick
  is YAML syntax, and sops refuses to save the file. Single-quote it. Double
  quotes work too but treat `\` as an escape, so check what sops shows after it
  rewrites the value in its own style. (2026-09-25)
- **`luks_passphrase`** is the only plaintext credential that must never reach
  `/run/secrets`: `cryptsetup` needs the passphrase, not a hash of it.
  `install.sh` decrypts it, runs `luksFormat` and shreds its copy, and
  `modules/sops.nix` deliberately does not declare it. You still type it at
  every boot; nothing on the machine can open its own disk.
- **The password hashes** must be crypt(3) hashes. A `sha512sum` digest is not
  one, and with `users.mutableUsers = false` a host that cannot use its hashes
  is a host nobody can log into.

## Templates

`modules/sops.nix` also renders three files out of those keys, because the
consumers want a file of a particular shape rather than a bare value:

| Template          | Shape                                    | Why                                                        |
| ----------------- | ---------------------------------------- | ---------------------------------------------------------- |
| `llm.env`         | `VAR=value` lines                        | `dot-profile.d/environment.sh` sources it into every shell |
| `git-credentials` | git's credential-store format, root-only | `sudo nixos-rebuild` fetches private inputs as root        |
| `sunshine-netrc`  | a curl netrc                             | the desktop's disconnect watcher, without argv exposure    |

## Keys and recipients

Adding a recipient does not grant access to what is already encrypted; rerun
`sops updatekeys secrets/secrets.yaml`. Lose every private key in `.sops.yaml`
and the values are gone, by design.

Getting the private key onto a new machine is the one unavoidable manual step
of an install. Nothing bootstraps a decryption key from nothing.
