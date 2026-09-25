# The VM and the install rehearsal

Two ways to test without touching a real machine, for two different layers.

| You changed                                                                 | Use                  |
| --------------------------------------------------------------------------- | -------------------- |
| anything in `modules/desktop/`, `home/`, or the dotfiles                    | `nix run .#vm`       |
| `install.sh`, `modules/disk-layout.nix`, `modules/sops.nix`, the bootloader | `vm/install-test.sh` |

## `nix run .#vm`

Builds `hosts/hutao-vm`: the real desktop layer and `home/`, under QEMU, with no
install. Log in as `hutao` / `vm`; sshd is forwarded to port 2223.

It does not import `hosts/common`, so there is no LUKS, no sops, no Tailscale
and no Syncthing. Throwaway accounts stand in for the sops-backed ones. It stops
at the greeter on purpose, since that is usually what you booted it to see.

## `vm/install-test.sh`

`install.sh` end to end against a blank virtual disk: disko, LUKS, LVM, the
sops bootstrap, Limine and first boot. Much slower, and only for the install
path.

```bash
vm/install-test.sh all          # the whole rehearsal
vm/install-test.sh up           # or one stage at a time:
                                # build up install boot unlock shot ssh down clean
```

It reads the real `secrets/secrets.yaml` with your real age key, because
proving that key works is the point. Its only state is `$WORK`
(`~/.cache/nixos-vm-test` by default); `SEED=0` skips seeding the guest store
from the host.
