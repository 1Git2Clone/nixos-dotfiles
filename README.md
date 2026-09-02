# nixos-dotfiles

NixOS system config for `hutao-laptop` (Lenovo IdeaPad 1 15AMN7). LVM-on-LUKS,
immutable users from sops, Hyprland + caelestia, on `nixos-unstable`.

`~/dotfiles` is still the user layer, stowed as on Arch. This repo makes sure
every binary those configs call exists.

## Disk layout

```text
nvme
├── p1  ESP   2G    vfat, unencrypted  -> /boot
└── p2  LUKS2       "cryptroot"        one passphrase at boot
      └── LVM PV -> vg "pool"
            ├── lv swap  20G   hibernation resume target
            ├── lv root  120G  ext4 -> /
            └── lv home  rest  ext4 -> /home
```

One encrypted container holds the whole VG, so you type one passphrase, not
three. Sizes live in `hosts/hutao-laptop/disk.nix`.

## Commands

| | |
| --- | --- |
| `nix run .#vm` | boot the desktop in QEMU (`hutao` / `vm`) |
| `nix develop -c pre-commit run --all-files` | lint |
| `nix eval '.#nixosConfigurations.hutao-vm.config.system.build.toplevel.drvPath'` | check it evaluates |
| `vm/install-test.sh all` | full install rehearsal |
| `nix build .#installer-iso` | installer ISO |
| `sudo nixos-rebuild switch --flake .#hutao-laptop` | rebuild |

## Install: existing host

Needs UEFI, and your age key on the machine.

```bash
nix build .#installer-iso
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot it, then from your workstation:

```bash
scp ~/.sops-nix/key.txt nixos@<ip>:/tmp/age.key
ssh nixos@<ip>
```

On the target:

```bash
sudo -i
git clone https://git.hu-tao.dev/hutao/nixos-dotfiles && cd nixos-dotfiles
INSTALL_AGE_KEY=/tmp/age.key ./install.sh
```

It prompts for the LUKS passphrase and the `hutao` / `root` passwords, and
refuses to continue until you confirm the disk by typing its size.

The age key is the one unavoidable manual step: a machine cannot bootstrap a
decryption key from nothing, and without one activation cannot render the
password hashes — leaving a machine with no way in.

Add your own SSH key to `vm/authorized_keys` before writing the ISO, or you
cannot reach the installer over the network.

## Install: a new machine

`install.sh` is hardcoded to `hutao-laptop`. For different hardware:

```bash
# 1. hardware config, from the live environment
nixos-generate-config --no-filesystems --dir /tmp/hw
mkdir -p hosts/<name>
cp /tmp/hw/hardware-configuration.nix hosts/<name>/

# 2. disk layout — copy and edit sizes
cp hosts/hutao-laptop/{disko.nix,disk.nix} hosts/<name>/
```

`hosts/<name>/default.nix`:

```nix
_: {
  imports = [
    ../common
    ./disko.nix
    ./hardware-configuration.nix
  ];
  networking.hostName = "<name>";
  system.stateVersion = "26.05"; # never change after install
}
```

Add it to `flake.nix` beside `hutao-laptop`, swapping the `nixos-hardware`
profiles, then run `install.sh` with `HOST=<name>` edited at the top.

`hosts/common` gives you the bootloader, kernel pin, graphics, users and sops.
Nothing in `.sops.yaml` changes — the same age key covers every machine.

## VM

`nix run .#vm` builds `hosts/vm` and boots it: the real `modules/desktop.nix`
and `modules/neovim.nix`, no install, no LUKS, no sops. Stops at the greeter;
sshd on 2223.

Use this for anything in the desktop layer. `vm/install-test.sh` is only for
changes to the install path — `install.sh`, `disko.nix`, `modules/sops.nix`,
the bootloader.

## Secrets

One personal age key, at `~/.sops-nix/key.txt` on a workstation and
`/var/lib/sops-nix/key.txt` on each host. Recipients are in `.sops.yaml`
(public keys, committed on purpose).

```bash
SOPS_AGE_KEY_FILE=~/.sops-nix/key.txt nix develop -c sops secrets/secrets.yaml
sudo nixos-rebuild switch --flake .#hutao-laptop
```

Adding a recipient does not grant access retroactively — rerun
`sops updatekeys secrets/secrets.yaml`. Lose every key in `.sops.yaml` and the
values are gone.

Keys are flat snake_case; nesting goes in `key = "section/name"`. See
`modules/sops.nix`.

## After the first boot

home-manager runs before you stow, which is the safe order — it creates
`~/.config/caelestia/` as a real directory so stow symlinks files inside it
rather than replacing it.

```bash
git clone <dotfiles> ~/dotfiles && cd ~/dotfiles && ./stow-setup.sh
cp ~/nixos-dotfiles/reference/monitors.lua ~/dotfiles/dot-config/hypr/modules/monitors.lua
```

`monitors.lua` is **required** — `hyprland.lua` requires it, it is gitignored
in the dotfiles repo, and without it Hyprland loads no config at all. Check
the output name with `hyprctl monitors all` first.

Then, when convenient:

- delete the `polkit-gnome` and `geoclue` lines from `autostart.lua` — both
  are systemd services here and those absolute Arch paths do not exist
- do not `systemctl --user enable ydotoold`; `programs.ydotool` provides it
- `caelestia scheme list` should show hu-tao; if not, find where the CLI
  actually looks and fix the path in `home/hutao.nix`

## Notes

- **SDDM is themed by hand.** Stylix has no `sddm` target (only `lightdm` and
  `regreet`). The greeter is `assets/sddm-hu-tao/` — swap the background by
  replacing `Backgrounds/hu-tao.png`.
- **`~/.config/nvim` is read-only**, pinned by the `nvim-config` flake input.
  `:Lazy update` cannot write the lockfile; use `nix flake update nvim-config`.
- **mason is disabled on NixOS.** Its prebuilt binaries cannot run here, so
  `modules/neovim.nix` provides the servers instead. Add one there and to
  nvim-config's `servers` table together, or it silently never attaches.
- **Suspend/resume** is the known hazard on this model (fixed by DMI quirks in
  Linux 6.6, so unstable is fine). Start there if it misbehaves.
