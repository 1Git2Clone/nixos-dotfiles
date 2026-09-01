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
| `home/hutao.nix` | home-manager: caelestia shell (thin, on purpose) |
| `verify.sh` | evaluate the flake in a container, no NixOS needed |
| `reference/monitors.lua` | laptop monitor config — gitignored in dotfiles |
| `schemes/hu-tao-dark.txt` | the caelestia scheme itself |
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

## Verifying before install

```bash
./verify.sh
```

Runs the real Nix evaluator in a container against a stubbed
`hardware-configuration.nix` and stubbed secrets. It catches wrong option
names and module conflicts — the class of error that would otherwise strand
you on a live ISO at 2am.

It does **not** build anything and does not prove the system boots. It proves
the configuration evaluates.

`install.sh` runs the same evaluation on the target before disko touches the
disk, so a bad config costs a minute rather than the disk.

## Relationship to the dotfiles repo

This repo is the **system**. `~/dotfiles` (branch `main`) is still the
**user** layer, stowed exactly as on Arch:

```bash
git clone <dotfiles> ~/dotfiles && cd ~/dotfiles && ./stow-setup.sh
```

Hyprland's config — `hyprland.lua` and `modules/*.lua` — comes from there
untouched. This repo's job is to make sure every binary those keybinds invoke
actually exists, and to provide the services the config assumes.

### Post-install steps that are NOT automated

**1. `monitors.lua` must be created or Hyprland will not load.**

`hyprland.lua` does `require("modules.monitors")`, but
`dot-config/hypr/modules/monitors.lua` is gitignored — it is setup-specific
and does not exist in a fresh clone. Without it Hyprland fails to load its
config and you get a bare compositor with no keybinds.

```bash
cp ~/nixos-dotfiles/reference/monitors.lua \
   ~/dotfiles/dot-config/hypr/modules/monitors.lua
```

Check the panel name first with `hyprctl monitors all`.

**2. Two `autostart.lua` lines are dead on NixOS.**

```lua
hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")
```

Neither FHS path exists here. Both services are declared in
`modules/desktop.nix` instead — polkit-gnome as a systemd user unit, geoclue
via `services.geoclue2` — so they are already running and these two lines
just fail harmlessly. Delete them when convenient.

**3. `~/.config/systemd/user/ydotoold.service` is superseded.**

It hardcodes `/usr/bin/ydotoold`. `programs.ydotool.enable = true` provides
the daemon properly. Do not `systemctl --user enable ydotoold` on this
machine.

**4. Stow and home-manager both touch `~/.config` — order matters.**

home-manager activates during the **first boot**, before you clone and stow
the dotfiles. That order is the safe one: home-manager creates
`~/.config/caelestia/schemes/` and `~/.config/systemd/user/` as real
directories, so stow then descends into them and symlinks individual files
alongside, rather than replacing the whole directory.

If you stow *first*, stow may symlink `~/.config/caelestia` as a single
directory link into the dotfiles repo, which shadows the scheme home-manager
placed there.

`stow-setup.sh` uses `stow --adopt`, which **moves** conflicting files into
the dotfiles repo. It has no reason to touch a `/nix/store` symlink, but
after your first stow run:

```bash
cd ~/dotfiles && git status --short
```

If anything unexpected got adopted, `git restore` it.

**5. `Hutao-Cursor` comes from stow and works.**

It is tracked (`!/dot-local/share/icons/Hutao-Cursor`, 95 files) and lands in
`~/.local/share/icons/`. `env.lua` sets `XCURSOR_THEME` to it. Stylix's
cursor setting is only a fallback for apps that ask Stylix rather than read
the env var.

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#hutao-laptop
```

`disko` **never runs** during a rebuild. After install, `disko.nix` is inert
description — it cannot repartition anything.

## Carried over from the Arch setup

### Packages

`modules/desktop.nix` ports `required_packages_archlinux.txt` **plus
everything the stowed configs actually call.** The hand-maintained Arch list
had drifted: `ydotool`, `grim`, `slurp`, `swappy`, `tesseract`, `cliphist`,
`wlogout`, `espanso`, `gammastep`, `libnotify` and `jq` are all invoked by
`dot-config/programs/shell_scripts/` or by keybinds in `keybindings.lua`, and
none of them were in the list.

That drift is the thing this repo structurally prevents: if a package is not
declared here, it is not on the machine.

Dropped deliberately: `paru` (AUR helper, no meaning here), `picom` (X11
compositor, unused under Wayland), `base`/`base-devel`/`fakeroot`/`sudo`
(provided by NixOS itself).

### System tuning

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

## The shell

[caelestia](https://github.com/caelestia-dots/shell) — Quickshell, and the
one Quickshell desktop with a **first-party** home-manager module rather than
a third-party flake.

It is the only reason home-manager is here. `home/hutao.nix` is deliberately
thin: it enables the shell and nothing else. Everything else in `~/.config`
still comes from stow.

Stylix's home-manager targets come along for free — its NixOS module detects
home-manager and wires them itself, so kitty, GTK and Qt now get the hu-tao
palette too, not just SDDM and the console.

### shell.json has one owner: stow

`programs.caelestia.settings` is left empty. Upstream warns that option
defaults drift across updates and leave a stale config, and
`~/.config/caelestia/shell.json` already comes from stow. Move settings into
Nix later if you want them declarative — but pick one owner, not both.

### What this retires

`caelestia/install.sh` in the dotfiles repo — the dependency checks, the
`python3 -c` scheme-directory lookup, the sudo guard — is all replaced by
`programs.caelestia.enable = true`.

Its one trick that does *not* port: it sudo-copied the hu-tao scheme into the
caelestia Python package's own data directory. `/nix/store` is read-only, so
the scheme is placed in the user config dir instead. **Verify on first boot**
with `caelestia scheme list`; if hu-tao is missing, find where the CLI
actually looks and adjust the `xdg.configFile` path in `home/hutao.nix`.

### Considered and rejected

[pctrade/end4-pC](https://github.com/pctrade/end4-pC) needs
illogical-impulse, which has no upstream Nix support — only third-party
flakes, the most prominent being 7 commits and self-described as incomplete.
end4-pC itself is only QML files in `~/.config/quickshell/`, so switching
later means declaring illogical-impulse's dependencies and stowing the
configs — not a migration.

## Not here yet

- moving more of `~/.config` off stow and into home-manager, if the
  declarative version earns its keep

## Hardware note

This model (82VG/82X5) was among nine Lenovo AMD laptops with NVMe IOMMU page
faults on suspend/resume, fixed by DMI quirks in **Linux 6.6**. Unstable is
far past that. If suspend ever misbehaves, start there.
