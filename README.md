# nixos-dotfiles

Core system configuration for `hutao-laptop` — a Lenovo IdeaPad 1 15AMN7
(Ryzen 3 7320U "Mendocino", Radeon 610M, 8GB soldered LPDDR5, NVMe).

Declarative disk layout, encrypted root, immutable users seeded from
sops-encrypted hashes, on `nixos-unstable`.

## Layout

```text
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
| --- | --- |
| `flake.nix` | inputs, the three configurations, packages, apps, dev shells |
| `install.sh` | one-shot install from a NixOS live environment |
| **hosts** | |
| `hosts/common/default.nix` | what every real machine shares: Limine, kernel, users, secrets |
| `hosts/hutao-laptop/default.nix` | laptop-only: hostname, amdgpu KMS, stateVersion |
| `hosts/hutao-laptop/disko.nix` | the disk layout above |
| `hosts/hutao-laptop/disk.nix` | device path + LV sizes (written by `install.sh`) |
| `hosts/hutao-laptop/hardware-configuration.nix` | generated at install |
| `hosts/vm/default.nix` | the desktop under QEMU, no install needed |
| `hosts/installer/default.nix` | installer ISO with ssh keys and a serial console |
| **modules** | |
| `modules/system.nix` | sysctl, zram, scx, I/O scheduler, nix settings |
| `modules/sops.nix` | every sops key, and which identities can decrypt |
| `modules/users.nix` | immutable users, consuming the rendered paths |
| `modules/desktop.nix` | Hyprland, SDDM, Stylix, pipewire, fcitx5 |
| **theme and assets** | |
| `hu-tao.yaml` | base16 scheme derived from your caelestia palette |
| `schemes/hu-tao-dark.txt` | the caelestia scheme itself |
| `assets/Hutao-Cursor/` | the cursor theme, vendored from the dotfiles repo |
| `pkgs/hutao-cursor.nix` | that theme, wrapped as a package |
| `home/hutao.nix` | home-manager: caelestia + neovim (thin, on purpose) |
| **testing** | |
| `vm/install-test.sh` | the install rehearsal — disko, LUKS, sops, Limine |
| `vm/authorized_keys` | who may ssh into the installer ISO |
| `verify.sh` | evaluate the flake in a container, no NixOS needed |
| `.pre-commit-config.yaml` | the checks, run locally and in CI from one list |
| **other** | |
| `.sops.yaml` | age recipients — public keys, committed on purpose |
| `secrets/secrets.yaml` | sops-encrypted password hashes (safe to commit) |
| `reference/monitors.lua` | laptop monitor config — gitignored in dotfiles |

## Install

From a NixOS live environment, booted **UEFI**:

```bash
git clone https://git.hu-tao.dev/hutao/nixos-dotfiles
cd nixos-dotfiles
sudo -i
nix-shell -p sops age ssh-to-age mkpasswd git --run ./install.sh
```

**You must bring your age key with you.** It is the one step that cannot be
automated — a machine cannot bootstrap a decryption key from nothing:

```bash
# from your workstation, once the installer is up
scp ~/.sops-nix/key.txt nixos@<installer-ip>:/tmp/age.key
# then, on the installer
INSTALL_AGE_KEY=/tmp/age.key ./install.sh
```

The script prompts for the LUKS passphrase and the `hutao` / `root`
passwords. None are echoed, and none are written to disk in plaintext except
a transient LUKS keyfile that is shredded on exit — including on failure.

It refuses to proceed until you confirm the target disk by typing its size.

### What it does, in order

1. Preflight: root, UEFI, required tools, substituter reachability, **and
   that your age key is actually a recipient in `.sops.yaml`**
2. Disk selection, with a destructive-action confirmation
3. Reads credentials
4. Hashes the passwords with `mkpasswd -m sha-512` and encrypts them into
   `secrets/secrets.yaml`, then **decrypts them again to prove the round trip**
5. Pins the disk path into `disk.nix`
6. Captures `hardware-configuration.nix` with `--no-filesystems`
7. Evaluates the flake — before anything destructive
8. Runs `disko` (destroy, format, mount)
9. **Seeds the age key into `/mnt/var/lib/sops-nix/key.txt` before installing**
10. `nixos-install`

Steps 6 and 7 are in that order for a reason that is not obvious. The flake
imports `hardware-configuration.nix`, so it cannot evaluate until that file
exists — generate it after `disko` (the intuitive order) and the pre-disko
evaluation fails every time on a fresh clone, which defeats the point of
evaluating early. `--no-filesystems` is what makes the early capture correct:
it reports kernel modules, microcode and host platform, none of which need the
target mounted.

Steps 1, 4 and 9 are the ones that matter, and they all guard the same
failure. `nixos-install` runs activation, which renders the password hashes.
With `users.mutableUsers = false` and no usable key in place, the install
fails at its final step and you get a machine with no way in. Step 1 catches
the wrong key in a second, step 4 catches an unreadable file before the disk
is touched, and step 9 puts the key where activation will look for it.

## Secrets

One personal age key, held by you, is the primary recipient — the same key
that already decrypts the `vps` repo, so a single identity covers every
machine you own. It lives at `~/.sops-nix/key.txt` on a workstation and
`/var/lib/sops-nix/key.txt` on each installed host.

### Why not the machine's SSH host key

That was the original design here and it is a trap. Making the host's own
ed25519 key the *only* recipient means:

- the file is readable by exactly one machine, so you cannot edit it from the
  workstation you write the config on
- reinstalling regenerates the host key, and every encrypted value becomes
  permanently unreadable
- a second machine cannot share a secret, so `hutao-desktop` would need its
  own parallel file

The host key is not listed as a fallback identity either. It is not a
recipient in `.sops.yaml`, so declaring it would only add an identity that can
never actually decrypt — configuration implying a capability it does not have.

### How keys are declared

`modules/sops.nix` follows the same shape as the vps repo: attribute names are
flat and snake_case, and nesting in the YAML is expressed with
`key = "section/name"` rather than by nesting the Nix. A grouped file like

```yaml
backups:
  restic_password: …
```

is declared as `backups_restic_password = { key = "backups/restic_password"; }`
and read at `config.sops.secrets.backups_restic_password.path`. The two
entries here today — `root_password` and `user_password` — are top-level, so
they need no `key`.

`user_password` rather than `hutao_password` on purpose: the same encrypted
file is meant to serve `hutao-desktop` too, and the account is `hutao` on
both.

`neededForUsers = true` puts the hashes in `/run/secrets-for-users`, which is
populated before user creation — the only mechanism that works with immutable
users.

`root` gets a hash too. It is the emergency door: if the display manager or
the `hutao` account breaks, you can still reach a TTY.

### Editing secrets later

```bash
SOPS_AGE_KEY_FILE=~/.sops-nix/key.txt nix develop -c sops secrets/secrets.yaml
sudo nixos-rebuild switch --flake .#hutao-laptop
```

Only recipients listed in `.sops.yaml` can decrypt, and adding one afterwards
does **not** grant access retroactively — the file must be rewritten with
`sops updatekeys secrets/secrets.yaml`. That is why `.sops.yaml` lists a
backup key up front rather than leaving it for later.

Lose every private key listed there and the values are gone. There is no
recovery path, by design.

## Testing

Three levels, cheapest first. Each one catches a class of failure the level
below it cannot see.

| Level | Command | Catches | Cost |
| --- | --- | --- | --- |
| lint | `nix develop -c pre-commit run --all-files` | formatting, nix antipatterns, shell bugs, leaked tokens | seconds |
| evaluate | `nix eval '.#nixosConfigurations.hutao-vm.config.system.build.toplevel.drvPath'` | renamed packages, wrong option names, module conflicts | ~1 min |
| boot the desktop | `nix run .#vm` | does Hyprland/SDDM/caelestia actually come up | ~20 min first time |
| rehearse the install | `vm/install-test.sh all` | disko, LUKS, LVM, the sops bootstrap, Limine, first boot | ~45 min |

### Lint

`pre-commit` runs nixfmt, statix, deadnix, shellcheck, shfmt, markdownlint and
gitleaks. `.github/workflows/ci.yml` runs the *same file*, so a check cannot
pass locally and fail in CI.

```bash
nix develop -c pre-commit install       # once, per clone
```

### Evaluate

`hutao-vm` rather than `hutao-laptop`: the laptop config needs
`hardware-configuration.nix` and the encrypted hashes, neither of which exists
in a fresh clone. `hutao-vm` shares every module that breaks this way —
`modules/system.nix`, `modules/desktop.nix`, home-manager, stylix, caelestia —
so it is the honest thing to evaluate.

`verify.sh` does the same in a Docker container, for a machine with no Nix.

`install.sh` runs the evaluation on the target before disko touches the disk,
so a bad config costs a minute rather than the disk.

### Boot the desktop

`nix run .#vm` builds `hosts/vm/default.nix` and boots it in QEMU. No install,
no LUKS, no sops — just the desktop layer, with `hutao` / `vm` as the login
and sshd on port 2223.

QEMU has no GPU, so the VM sets `WLR_RENDERER_ALLOW_SOFTWARE` and friends;
Hyprland refuses to start on llvmpipe without them. That is a VM-only
workaround, not something the laptop needs.

### Rehearse the install

`vm/install-test.sh` boots a purpose-built installer ISO against a blank
512G virtual NVMe and runs `install.sh` end to end, exactly as it will run on
the laptop — same script, same non-interactive path, same age key.

```bash
vm/install-test.sh all      # or: build / up / install / boot / unlock / shot
```

The ISO (`hosts/installer/default.nix`) exists because the stock one cannot be
automated: it leaves `nixos` and `root` with **empty** passwords, and sshd
refuses empty-password logins, so there is no way in over the network until
someone types `passwd` at the physical console. This one carries authorized
keys, a serial console, and the tools `install.sh` preflights for.

It is worth writing to a USB stick for the real install too — add your own
public key to `vm/authorized_keys` first, then:

```bash
nix build .#installer-iso
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### What verification has found so far

| Check | Result |
| --- | --- |
| all flake inputs resolve | pass — incl. caelestia's quickshell from git.outfoxxed.me |
| `caelestia.homeManagerModules.default` exists | pass — `homeModules` does *not*, the guess was right |
| `fcitx5-configtool` | **FAIL** — renamed to `qt6Packages.fcitx5-configtool`, fixed |
| `pinentry` | **FAIL** — removed, needs a variant; now `pinentry-gnome3`, fixed |
| `xorg.xauth` / `xorg.xhost` | **FAIL** — `xorg` set deprecated, now `xauth` / `xhost`, fixed |
| full `hutao-vm` eval | **pass** — every package name and `stylix.*` option resolves |
| installer ISO builds | **pass** |
| `hutao-cursor` builds | **pass** — 94 entries, all 77 name-hash symlinks intact |
| sops creation rule | **FAIL** — `install.sh` encrypted from `/tmp`, which never matched `secrets/<name>.yaml`; it now writes in place |
| `install.sh` step order | **FAIL** — the pre-disko evaluation needed `hardware-configuration.nix`, which was only generated after disko, so it could never succeed on a fresh clone; detection moved earlier |
| `install-test.sh` ssh wait | **FAIL** — `(( … )) && { … }` under `set -e` aborted the wait loop on its first iteration; now an `if` |
| disko's wipe prompt | **FAIL** — prompts on stdin, unanswerable over ssh; `--yes-wipe-all-disks` now passed in non-interactive mode only |
| target swap | **FAIL** — disko formats the swap LV but never activates it, and the live `/` is tmpfs, so `nixos-install` was OOM-killed (exit 137) building the initrd. Now `swapon` before the build |
| `sops.age.sshKeyPaths` | **FAIL** — sops-nix defaults it from `services.openssh.hostKeys`, so activation still tried a host key that does not exist yet; now explicitly `[ ]` |
| **install end to end** | **pass** — `installation finished!` |
| **first boot** | **pass** — Limine → initrd → LUKS unlock → LVM → SDDM greeter |
| **login as `hutao`** | **pass** — the sops-decrypted hash authenticates |
| **Hyprland session** | **pass** — starts even in QEMU with no GPU; screen is a solid `#130a0c`, the `stylix.image` placeholder |
| SDDM theming | **FAIL** — no `stylix.targets.sddm` exists; greeter is stock blue. See Theming |

The package names previously listed as unverified — `ntfs3g`, `hyprpicker`,
`swappy`, `gammastep`, `espanso`, `trash-cli`, `polkit_gnome`, `dejavu_fonts`,
`liberation_ttf`, `nerd-fonts.jetbrains-mono` — are all confirmed by the full
evaluation above.

The rehearsal has now been run end to end against a blank 512G virtual NVMe
and the installed system boots, unlocks and logs in. Four of the failures
above — the disko prompt, the swap, the step order and `sshKeyPaths` — were
found only by running it, not by reading it, and three of the four would have
stopped a real install dead.

Still unproven, and only real hardware can say:

- **suspend/resume**, the one known hazard on this model (see Hardware note)
- **the caelestia shell**, which needs `~/dotfiles` stowed; the VM boots to a
  bare themed Hyprland with no bar
- **amdgpu**, since QEMU has no GPU — the VM proves the session starts, not
  that it accelerates

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

**5. `Hutao-Cursor` no longer comes from stow — it is a package here.**

It used to be a stowed directory in `~/.local/share/icons`, which made the
cursor a *user* artifact: SDDM and the greeter could not see it, and Stylix
had nothing real to point at, so `stylix.cursor` was a Bibata placeholder that
never matched what `env.lua` asked for.

`assets/Hutao-Cursor/` is now vendored here and wrapped by
`pkgs/hutao-cursor.nix`, so it lands in `/run/current-system/sw/share/icons`
where `XCURSOR_PATH` already looks. `env.lua`'s `XCURSOR_THEME` and
`stylix.cursor` finally name the same theme, and the greeter matches the
session from first boot — before `~/dotfiles` has even been cloned.

The 77 hex-named entries in `cursors/` are symlinks to the 17 real files; X11
addresses cursors by a name hash rather than a human name, and dropping them
breaks the pointer in GTK apps specifically. The package preserves them.

**6. Neovim comes from the flake, not from stow.**

`github:1Git2Clone/nvim-config` is a pinned flake input, symlinked to
`~/.config/nvim` by home-manager. This replaces that repo's `stow_setup.sh`.

The tradeoff, because it will surprise you once: `/nix/store` is read-only, so
`:Lazy update` cannot write `lazy-lock.json` back. Plugins still install fine
(they go to `~/.local/share/nvim`). Moving plugins is:

```bash
nix flake update nvim-config
sudo nixos-rebuild switch --flake .#hutao-laptop
```

`home/hutao.nix` documents the one-line swap to an out-of-store symlink if you
would rather hack on the config in place.

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
| --- | --- |
| `sysctl.d/99-custom.conf` | `boot.kernel.sysctl` in `modules/system.nix` |
| `udev/rules.d/60-io-scheduler.rules` | `services.udev.extraRules` |
| hand-written `scx-lavd.service` | `services.scx = { enable = true; scheduler = "scx_lavd"; }` |
| `networkd-dispatcher/50-tailscale` | `services.tailscale.useRoutingFeatures` when Tailscale is enabled |

`scx` needs kernel 6.12+, so `kernelPackages` is pinned to
`linuxPackages_latest`.

## Theming

`hu-tao.yaml` is a base16 scheme derived from
`caelestia/schemes/hu-tao/default/dark.txt` in the dotfiles repo — the same
palette, remapped onto base16's sixteen slots. Stylix drives the TTY console,
GTK/Qt, the cursor and the Limine boot menu from it.

### SDDM is not themed, and cannot be by Stylix

This file used to claim Stylix drove SDDM. It does not, and never could —
there is no `stylix.targets.sddm`. The full NixOS target list is:

```text
chromium console feh fish fontconfig font-packages glance gnome
gnome-text-editor grub gtk gtksourceview kmscon lightdm limine nixos-icons
nixvim nvf plymouth qt regreet spicetify
```

The only display managers there are **lightdm** and **regreet**. The first
real boot confirmed it: the greeter comes up in stock SDDM blue while the
session behind it is correctly on `#130a0c`.

Three ways out, none of them done here:

1. switch to `regreet`, which Stylix themes for free and is Wayland-native
2. keep SDDM and theme it by hand — `services.displayManager.sddm.theme` plus
   a theme package, maintained separately from the base16 scheme
3. leave it. It is fifteen seconds of blue before a correctly themed session

`stylix.targets.limine` is enabled though, so the boot menu ahead of it does
follow the palette.

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
palette too, not just the console.

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

## Adding hutao-desktop

The split between `hosts/common` and a host directory exists for this. Common
holds the bootloader, the kernel pin, the graphics stack, users and secrets;
a host directory holds only what is true of that hardware.

To add the desktop:

1. `hosts/hutao-desktop/default.nix` — import `../common`, set
   `networking.hostName`, its own `system.stateVersion`, and whatever GPU
   handling it needs instead of the laptop's `initrd.kernelModules = [ "amdgpu" ]`
2. `hosts/hutao-desktop/disko.nix` + `disk.nix` — its own layout
3. `flake.nix` — a second `nixosConfigurations` entry reusing `desktopModules`,
   swapping the `nixos-hardware` laptop profiles for desktop ones
4. Nothing in `.sops.yaml` changes. The primary age key already covers it,
   which is the whole reason for not using per-host SSH keys as recipients.

Both machines then share one `secrets/secrets.yaml`, one desktop layer and one
bootloader configuration, and cannot drift apart on any of them.

## Not here yet

- moving more of `~/.config` off stow and into home-manager, if the
  declarative version earns its keep
- `hutao-desktop` itself — the seam is cut for it, but nothing is written

## Hardware note

This model (82VG/82X5) was among nine Lenovo AMD laptops with NVMe IOMMU page
faults on suspend/resume, fixed by DMI quirks in **Linux 6.6**. Unstable is
far past that. If suspend ever misbehaves, start there.
