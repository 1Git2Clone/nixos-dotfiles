# nixos-dotfiles

NixOS config on `nixos-unstable`: LVM-on-LUKS, immutable users from sops,
Hyprland + caelestia, Limine.

The user layer is `dotfiles/` and the neovim config is `nvim/`, both in this
repo, symlinked into `$HOME` by home-manager. No stow, and no flake input to
bump: a config change and the system change that needs it are one commit.

## Hosts

| | |
| --- | --- |
| `hutao-laptop` | Lenovo IdeaPad 1 15AMN7 — Ryzen 3 7320U, 8GB, NVMe |
| `hutao-desktop` | Ryzen 5 3600X, RX 5700 XT, 16GB, NVMe + an NTFS HDD it only mounts |
| `hutao-vm` | the desktop layer under QEMU, no install |

`hosts/common` gives every real machine the bootloader, kernel pin, graphics,
users and sops. `hosts/hutao-vm` skips it on purpose — all of it needs real
firmware or a real install.

## Commands

| | |
| --- | --- |
| `nix run .#vm` | boot the desktop in QEMU (`hutao` / `vm`) |
| `sudo nixos-rebuild switch --flake .#hutao-desktop` | rebuild |
| `nix develop -c pre-commit run --all-files` | lint |
| `nix eval '.#nixosConfigurations.hutao-vm.config.system.build.toplevel.drvPath'` | check it evaluates |
| `vm/install-test.sh all` | full install rehearsal |
| `nix build .#installer-iso` | installer ISO |
| `nix develop -c deploy .#hutao-laptop` | deploy to a host over Tailscale, with rollback |

## VM

`nix run .#vm` builds `hosts/hutao-vm` with the real `modules/desktop.nix`,
`modules/neovim.nix` and `home/hutao.nix`. No install, no LUKS, no sops, no
tailscale — it does not import `hosts/common`. It stops at the greeter; sshd is
on 2223.

Use it for anything in the desktop or user layer. `vm/install-test.sh` is only
for the install path — `install.sh`, `modules/disk-layout.nix`,
`modules/sops.nix`, the bootloader.

## Install

Needs UEFI, your age key on the machine, and `secrets/secrets.yaml` already
populated — see [Secrets](#secrets).

```bash
nix build .#installer-iso
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Add your SSH key to `vm/authorized_keys` before writing the ISO or you cannot
reach the installer over the network. Boot it, then from your workstation:

```bash
scp ~/.sops-nix/key.txt nixos@<ip>:/tmp/age.key
ssh nixos@<ip>
```

### On a host this repo already knows

```bash
sudo -i
git clone https://git.hu-tao.dev/hutao/nixos-dotfiles && cd nixos-dotfiles
INSTALL_AGE_KEY=/tmp/age.key HOST=hutao-desktop ./install.sh
```

Every credential comes out of `secrets/secrets.yaml` — the LUKS passphrase,
both password hashes and the Tailscale auth key. `install.sh` prompts for none
of them and refuses to start if any is missing or malformed. It still refuses
to continue until you confirm the disk by typing its size.

### On new hardware

Four files, then the same `install.sh`.

```bash
# 1. hardware config — from the live environment, before disko
nixos-generate-config --no-filesystems --dir /tmp/hw
mkdir -p hosts/<name>
cp /tmp/hw/hardware-configuration.nix hosts/<name>/

# 2. disk sizes and the target device
cp hosts/hutao-desktop/disk.nix hosts/<name>/
```

`--no-filesystems` is required: `modules/disk-layout.nix` owns `fileSystems.*`.

`hosts/<name>/monitors.lua` — `hyprland.lua` requires it and it is gitignored
upstream, so an empty file is the minimum. Get real names from
`hyprctl monitors all`; copy `hosts/hutao-desktop/monitors.lua` for the shape.

`hosts/<name>/default.nix`:

```nix
_: {
  imports = [
    ../common
    (import ../../modules/disk-layout.nix (import ./disk.nix))
    ./hardware-configuration.nix
  ];
  networking.hostName = "<name>";
  system.stateVersion = "26.05"; # never change after install
}
```

Then add it to `flake.nix` beside `hutao-desktop`, swapping the
`nixos-hardware` profiles for the CPU and GPU you have.

## User layer

`home/hutao.nix` replays `stow --dotfiles`: it walks the dotfiles tree, honours
`dotfiles/.stow-local-ignore`, renames `dot-foo` to `.foo`, and symlinks
the result out of the store. Nothing is listed by hand, so nothing gets
forgotten when the dotfiles gain a file.

Three things sit on top of the plain tree:

- **NixOS patches**, applied with `--replace-fail` — `/usr/bin/nvim`, the
  hardcoded FHS `XDG_DATA_DIRS` that leaves every launcher empty, and
  `autostart.lua`'s absolute `/usr/lib` paths. Delete each one as it lands in
  `dotfiles/`; a stale patch is a build error, not a silent no-op. Two of
  them substitute store paths and have to stay build-time patches; the rest
  could now simply be edited in place.
- **`monitors.lua`**, per host, because it is gitignored upstream and
  `hyprland.lua` requires it.
- **State that has to stay writable**: `lazy-lock.json` / `lazyvim.json`,
  caelestia's active scheme, and `~/Pictures/Wallpapers`. Each is seeded once
  from the tracked copy and then left alone, so `:Lazy update` and
  `caelestia scheme set` still work.

## Deploys

`deploy.nodes` in `flake.nix` drives `deploy-rs` over Tailscale SSH:

```bash
nix develop -c deploy .#hutao-laptop        # build locally, activate remotely
nix develop -c deploy --dry-activate .#hutao-laptop
```

`sshUser = "root"` rather than sudo, so `security.sudo.wheelNeedsPassword`
stays true and the credential is the tailnet ACL — revocable from the admin
console instead of baked into the host. `hostname` is the MagicDNS name, so no
address is pinned in the repo.

`magicRollback` makes the target confirm itself over the tailnet after
activating and roll back if it cannot, which is the case that matters when the
link you deploy over is the one you might break. `autoRollback` covers a
failed activation.

It needs three things, all verified the hard way:

- **Nix on the deploying machine.** deploy-rs builds locally and activates
  remotely; a stock macOS shell cannot drive it.
- **MagicDNS on the deploying machine** (`tailscale set --accept-dns=true`),
  because `hostname` is the MagicDNS name. Without it, neither
  `hutao-laptop` nor `hutao-laptop.<tailnet>.ts.net` resolves and the copy step
  fails. The tailnet IP works as a fallback if you would rather not rely on DNS.
- **A different machine.** A host cannot deploy to itself over Tailscale SSH:
  the connection goes over loopback, tailscaled never intercepts it, and it
  lands on real sshd — which `PermitRootLogin = "no"` refuses. Use
  `nixos-rebuild switch` locally.

Also check the tailnet ACL does not force an interactive SSH re-auth, or
`magicRollback`'s confirmation will time out and roll back a good activation.

Plain `nixos-rebuild switch --flake .#<host>` still works and is simpler when
you are sitting at the machine; it just has no rollback on loss of contact.

## Secrets

One personal age key, at `~/.sops-nix/key.txt` on a workstation and
`/var/lib/sops-nix/key.txt` on each host. Recipients live in `.sops.yaml` —
public keys, committed on purpose. `secrets/secrets.example.yaml` shows the shape of
the decrypted file; `modules/sops.nix` declares which keys exist.

```bash
SOPS_AGE_KEY_FILE=~/.sops-nix/key.txt nix develop -c sops secrets/secrets.yaml
sudo nixos-rebuild switch --flake .#hutao-desktop
```

Four values, all required before an install:

| key | what | made with |
| --- | --- | --- |
| `root_password` | crypt(3) hash | `mkpasswd -m yescrypt` |
| `user_password` | crypt(3) hash | `mkpasswd -m yescrypt` |
| `luks_passphrase` | the passphrase itself, in the clear | your head |
| `tailscale_authkey` | reusable, pre-authorized, **not** ephemeral | [admin console](https://login.tailscale.com/admin/settings/keys) |

`luks_passphrase` is the odd one out and worth being clear about. It is the
only plaintext credential, because `cryptsetup` needs the passphrase and not a
hash of it. `install.sh` decrypts it, runs `luksFormat`, and shreds its copy;
`modules/sops.nix` does not declare it, so the installed system never renders
it to `/run/secrets`. **You still type it at every boot.** This is not
auto-unlock — the age key that decrypts it lives on your workstation and the
installer, never on the unencrypted ESP, so nothing on the machine can open its
own disk.

Adding a recipient does not grant access retroactively — rerun
`sops updatekeys secrets/secrets.yaml`. Lose every key in `.sops.yaml` and the
values are gone.

Getting the private key onto a new machine is the one unavoidable manual step:
nothing bootstraps a decryption key from nothing, and with
`users.mutableUsers = false` a host that cannot render its password hashes is a
host nobody can log into.

## Notes

- **`~/.config` is read-only.** It is symlinked into the store, so apps that
  persist settings there (fcitx5) cannot. To hack on the dotfiles in place,
  point `src` in `home/hutao.nix` at `mkOutOfStoreSymlink`.
- **`~/dotfiles` is a store symlink too**, because `dot-profile` hardcodes
  `$HOME/dotfiles/dot-profile.d`.
- **`~/.claude` is linked file by file**, not whole, so Claude Code keeps a
  writable directory for its own state.
- **`~/.config/nvim` is linked file by file too**, from the in-tree `nvim/`,
  so lazy.nvim gets a real directory to write `lazy-lock.json` into. Link it
  whole and that write fails, which aborts `init.lua` on every first boot.
- **SDDM is themed by hand.** Stylix has no `sddm` target (only `lightdm` and
  `regreet`). The greeter is `assets/sddm-hu-tao/` — swap the background by
  replacing `Backgrounds/hu-tao.png`.
- **Stylix's per-app targets are off** (`stylix.autoEnable = false`). The
  dotfiles already theme those apps, and two writers for one file is a
  conflict.
- **`dotfiles/` is exempt from markdownlint, shellcheck and shfmt**, because
  that tree's own linter configs stayed behind in the repo it came from. It is
  *not* exempt from the whitespace fixers or from gitleaks, both of which still
  cover it. See the closing note in `.pre-commit-config.yaml`.
- **mason is disabled on NixOS.** Its prebuilt binaries cannot run here, so
  `modules/neovim.nix` provides the servers instead. Add one there and to
  `nvim/lua/plugins/lspconfig.lua`'s `servers` table together, or it
  silently never attaches.
  `home/nvim-nixos.lua` silences the warning LazyVim's lang extras raise for
  every package mason has not installed.
- **Tailscale joins on first boot** with `--ssh`, from
  `sops.secrets.tailscale_authkey`. It lives in `hosts/common`, so real
  machines get it and `hutao-vm` does not. `useRoutingFeatures = "both"`
  replaces the `ip_forward` sysctls `modules/system.nix` used to set by hand.
  A used-up or expired auth key fails `tailscaled-autoconnect` at boot without
  blocking anything else — `systemctl status tailscaled-autoconnect` says so.
- **One LUKS keyslot, no recovery key.** Lose `luks_passphrase` and the disk is
  gone; there is no second slot and no escrow. LUKS2 has eight, so
  `cryptsetup luksAddKey /dev/disk/by-partlabel/...` after first boot is cheap
  insurance. Rotating is `cryptsetup luksChangeKey` — imperative either way,
  which is why neither lives in a module.
- **Suspend/resume** is the known hazard on the laptop (fixed by DMI quirks in
  Linux 6.6, so unstable is fine). Start there if it misbehaves.
