# nixos-dotfiles

Core system configuration for `hutao-laptop` — a Lenovo IdeaPad 1 15AMN7
(Ryzen 3 7320U "Mendocino", Radeon 610M, 8GB soldered LPDDR5, NVMe).

Declarative disk layout, encrypted root, immutable users seeded from
sops-encrypted hashes, on `nixos-unstable`.

## Layout

```
nvme
├── p1  ESP   2G    vfat, unencrypted  -> /boot     kernels + initrd
└── p2  LUKS2       "cryptroot"                     one passphrase at boot
      └── LVM PV -> vg "pool"
            ├── lv swap  20G   resume target (hibernation)
            ├── lv root  120G  ext4 -> /
            └── lv home  rest  ext4 -> /home
```

LVM-on-LUKS, not LUKS-on-LVM: a single encrypted container holds the whole
volume group, so you type one passphrase rather than three.

Swap is sized for hibernation on 16GB of RAM (`swap >= RAM`), not the 32G
originally specified — that would have spent 12G on space that can never be
used. Leaves ~370G for `/home`.

## Files

| Path | Purpose |
|---|---|
| `flake.nix` | inputs: nixpkgs unstable, disko, sops-nix, nixos-hardware |
| `install.sh` | one-shot install from a NixOS live environment |
| `hosts/hutao-laptop/default.nix` | boot, Limine, amdgpu, kernel |
| `hosts/hutao-laptop/disko.nix` | the disk layout above |
| `hosts/hutao-laptop/disk.nix` | device path + LV sizes (written by `install.sh`) |
| `hosts/hutao-laptop/hardware-configuration.nix` | generated at install |
| `modules/system.nix` | sysctl, zram, scx, I/O scheduler, nix settings |
| `modules/users.nix` | immutable users, sops wiring |
| `modules/desktop.nix` | Hyprland, SDDM, Stylix, pipewire, fcitx5 |
| `hu-tao.yaml` | base16 scheme derived from your caelestia palette |
| `secrets/secrets.yaml` | sops-encrypted password hashes (safe to commit) |

## Install

From a NixOS live environment, booted **UEFI**:

```bash
git clone https://git.hu-tao.dev/hutao/nixos-dotfiles
cd nixos-dotfiles
sudo -i
nix-shell -p sops age ssh-to-age mkpasswd git --run ./install.sh
```

The script prompts for the LUKS passphrase and the `hutao` / `root`
passwords. None are echoed, and none are written to disk in plaintext except
a transient LUKS keyfile that is shredded on exit — including on failure.

It refuses to proceed until you confirm the target disk by typing its size.

### What it does, in order

1. Preflight: root, UEFI, required tools, substituter reachability
2. Disk selection, with a destructive-action confirmation
3. Reads credentials
4. Generates the machine's ed25519 **host key** and converts it to an age
   recipient with `ssh-to-age`
5. Writes `.sops.yaml`, hashes the passwords with `mkpasswd -m sha-512`, and
   encrypts them into `secrets/secrets.yaml`
6. Pins the disk path into `disk.nix`
7. Runs `disko` (destroy, format, mount)
8. Captures `hardware-configuration.nix` with `--no-filesystems`
9. **Seeds the host key into `/mnt/etc/ssh` before installing**
10. `nixos-install`

Step 9 is the one that matters. `nixos-install` runs activation, which
decrypts the user password hashes. With `users.mutableUsers = false` and no
key in place, the install fails at the final step and you get a machine with
no way in.

## Secret bootstrapping

`sops.age.sshKeyPaths` points at `/etc/ssh/ssh_host_ed25519_key`, so the
machine's own SSH host identity *is* its decryption identity. Nothing extra
to back up, nothing to rotate separately.

`neededForUsers = true` puts the hashes in `/run/secrets-for-users`, which is
populated before user creation — the only mechanism that works with immutable
users.

`root` gets a hash too. It is the emergency door: if the display manager or
the `hutao` account breaks, you can still reach a TTY.

### Editing secrets later

```bash
sops secrets/secrets.yaml
sudo nixos-rebuild switch --flake .#hutao-laptop
```

Only recipients listed in `.sops.yaml` can decrypt. Adding one afterwards
requires `sops updatekeys`, which is why `install.sh` offers to add a second
recipient up front.

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#hutao-laptop
```

`disko` **never runs** during a rebuild. After install, `disko.nix` is inert
description — it cannot repartition anything.

## Carried over from the Arch setup

`system/install.sh` in the dotfiles repo is fully replaced:

| Arch | NixOS |
|---|---|
| `sysctl.d/99-custom.conf` | `boot.kernel.sysctl` in `modules/system.nix` |
| `udev/rules.d/60-io-scheduler.rules` | `services.udev.extraRules` |
| hand-written `scx-lavd.service` | `services.scx = { enable = true; scheduler = "scx_lavd"; }` |
| `networkd-dispatcher/50-tailscale` | `services.tailscale.useRoutingFeatures` when Tailscale is enabled |

`scx` needs kernel 6.12+, so `kernelPackages` is pinned to
`linuxPackages_latest`.

## Theming

`hu-tao.yaml` is a base16 scheme derived from
`caelestia/schemes/hu-tao/default/dark.txt` in the dotfiles repo — the same
palette, remapped onto base16's sixteen slots. Stylix drives SDDM, the TTY
console, GTK/Qt and cursors from it, so the system is themed before any
userspace config loads.

Fonts match `kitty.conf`: JetBrainsMono Nerd Font at 9pt, Noto Color Emoji
fallback.

`stylix.image` is currently a generated solid `#130a0c` field so the config
always evaluates. Point it at a real wallpaper when you have one — or delete
`base16Scheme` and let Stylix derive the palette from the image instead.

**Scope:** Stylix's NixOS module themes system-level targets. App-level
theming (kitty, neovim) needs the home-manager module, which would mean
moving those configs out of stow. That is a separate decision and is
deliberately not taken here.

## Not here yet

- the `illogical-impulse` shell, which has no upstream Nix packaging and will
  need either a community flake or a local derivation
- home-manager, if the app-level Stylix targets turn out to be worth it

## Hardware note

This model (82VG/82X5) was among nine Lenovo AMD laptops with NVMe IOMMU page
faults on suspend/resume, fixed by DMI quirks in **Linux 6.6**. Unstable is
far past that. If suspend ever misbehaves, start there.
