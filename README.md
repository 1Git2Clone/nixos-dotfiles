# nixos-dotfiles

NixOS config on `nixos-unstable`: LVM-on-LUKS, immutable users from sops,
Hyprland + caelestia, Limine.

The user layer is the [dotfiles](https://git.hu-tao.dev/hutao/dotfiles) repo,
pinned as a flake input and symlinked into `$HOME` by home-manager. No stow.

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
| `nix flake update dotfiles` | pull in a dotfiles change |
| `nix develop -c pre-commit run --all-files` | lint |
| `nix eval '.#nixosConfigurations.hutao-vm.config.system.build.toplevel.drvPath'` | check it evaluates |
| `vm/install-test.sh all` | full install rehearsal |
| `nix build .#installer-iso` | installer ISO |

## VM

`nix run .#vm` builds `hosts/hutao-vm` with the real `modules/desktop.nix`,
`modules/neovim.nix` and `home/hutao.nix`. No install, no LUKS, no sops. It
stops at the greeter; sshd is on 2223.

Use it for anything in the desktop or user layer. `vm/install-test.sh` is only
for the install path — `install.sh`, `modules/disk-layout.nix`,
`modules/sops.nix`, the bootloader.

## Install

Needs UEFI, and your age key on the machine — see [Secrets](#secrets).

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

It prompts for the LUKS passphrase and the `hutao` / `root` passwords, and
refuses to continue until you confirm the disk by typing its size.

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
that repo's own `.stow-local-ignore`, renames `dot-foo` to `.foo`, and symlinks
the result out of the store. Nothing is listed by hand, so nothing gets
forgotten when the dotfiles gain a file.

Three things sit on top of the plain tree:

- **NixOS patches**, applied with `--replace-fail` — `/usr/bin/nvim`, the
  hardcoded FHS `XDG_DATA_DIRS` that leaves every launcher empty, and
  `autostart.lua`'s absolute `/usr/lib` paths. Delete each one as it lands in
  the dotfiles repo; a stale patch is a build error, not a silent no-op.
- **`monitors.lua`**, per host, because it is gitignored upstream and
  `hyprland.lua` requires it.
- **State that has to stay writable**: `lazy-lock.json` / `lazyvim.json`,
  caelestia's active scheme, and `~/Pictures/Wallpapers`. Each is seeded once
  from the pinned copy and then left alone, so `:Lazy update` and
  `caelestia scheme set` still work.

## Secrets

One personal age key, at `~/.sops-nix/key.txt` on a workstation and
`/var/lib/sops-nix/key.txt` on each host. Recipients live in `.sops.yaml` —
public keys, committed on purpose. `docs/sops-example.yaml` shows the shape of
the decrypted file; `modules/sops.nix` declares which keys exist.

```bash
SOPS_AGE_KEY_FILE=~/.sops-nix/key.txt nix develop -c sops secrets/secrets.yaml
sudo nixos-rebuild switch --flake .#hutao-desktop
```

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
- **SDDM is themed by hand.** Stylix has no `sddm` target (only `lightdm` and
  `regreet`). The greeter is `assets/sddm-hu-tao/` — swap the background by
  replacing `Backgrounds/hu-tao.png`.
- **Stylix's per-app targets are off** (`stylix.autoEnable = false`). The
  dotfiles already theme those apps, and two writers for one file is a
  conflict.
- **mason is disabled on NixOS.** Its prebuilt binaries cannot run here, so
  `modules/neovim.nix` provides the servers instead. Add one there and to
  nvim-config's `servers` table together, or it silently never attaches.
  `home/nvim-nixos.lua` silences the warning LazyVim's lang extras raise for
  every package mason has not installed.
- **Suspend/resume** is the known hazard on the laptop (fixed by DMI quirks in
  Linux 6.6, so unstable is fine). Start there if it misbehaves.
