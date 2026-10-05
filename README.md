# nixos-dotfiles

[![CI Icon]][CI Status]&emsp;[![Pages Icon]][Pages Status]&emsp;[![Handbook Icon]][Handbook]&emsp;[![NixOS Icon]][NixOS]

[CI Icon]: https://git.hu-tao.dev/hutao/nixos-dotfiles/badges/workflows/ci.yml/badge.svg
[CI Status]: https://git.hu-tao.dev/hutao/nixos-dotfiles/actions
[Pages Icon]: https://git.hu-tao.dev/hutao/nixos-dotfiles/badges/workflows/pages.yml/badge.svg
[Pages Status]: https://git.hu-tao.dev/hutao/nixos-dotfiles/actions
[Handbook Icon]: https://img.shields.io/badge/docs-handbook-7aa2f7
[Handbook]: https://pages.hu-tao.dev/hutao/nixos-dotfiles/docs/
[NixOS Icon]: https://img.shields.io/badge/NixOS-unstable-7aa2f7
[NixOS]: https://git.hu-tao.dev/hutao/nixos-dotfiles/src/branch/main/flake.nix

NixOS config on `nixos-unstable` for a laptop and a desktop: LVM-on-LUKS,
immutable users from sops, Hyprland + caelestia, Limine.

The user layer is `dotfiles/`, symlinked into `$HOME` by home-manager, with no
stow. The neovim config is its own repo,
[nvim-config](https://git.hu-tao.dev/hutao/nvim-config), whose flake exports
the home-manager module that installs it.

```text
.
├── flake.nix              # the hosts, the installer ISO, the VM, deploy-rs nodes
├── hosts/
│   ├── common/            # what every real machine gets: boot, sops, tailscale, …
│   ├── hutao-laptop/      # IdeaPad 1 15AMN7
│   ├── hutao-desktop/     # the HDD, the printer, Sunshine
│   ├── hutao-vm/          # the desktop layer under QEMU
│   └── installer/         # the ISO install.sh runs from
├── modules/
│   ├── desktop/           # the desktop environment, shared by every host
│   ├── sops.nix           # every secret, declared
│   ├── disk-layout.nix    # disko: ESP + LUKS → LVM
│   └── firewall.nix tailscale.nix syncthing.nix users.nix system.nix flatpak.nix
├── home/                  # home-manager: the dotfiles walk, one file per app
├── dotfiles/              # the user layer itself
├── palette.nix            # the picked caelestia scheme, for what needs a rebuild
├── pkgs/                  # greeter, cursors, folder icons, app icons, CaelestiaFox
├── secrets/               # sops-encrypted values + a plaintext example
├── install.sh             # partition, encrypt, install, from the ISO
├── vm/                    # the install rehearsal
├── docs/                  # the handbook, mdBook source in docs/src/
└── AGENTS.md              # for agents: keep docs/ in step with every change
```

## The handbook

This README is the short version. The long version (what each layer holds, how
the colours flow, every secret and why, installing from nothing) is in
`docs/`, published at **<https://pages.hu-tao.dev/hutao/nixos-dotfiles/docs/>**.

```sh
nix run .#docs
```

| Chapter                                                                 | For                                                 |
| ----------------------------------------------------------------------- | --------------------------------------------------- |
| [Hosts and layers](docs/src/architecture/hosts.md)                      | where a change goes, and what each machine has      |
| [The user layer](docs/src/architecture/user-layer.md)                   | the dotfiles walk, its patches, what stays writable |
| [Colours](docs/src/architecture/colours.md)                             | pick a scheme in caelestia, and what follows it     |
| [Secrets](docs/src/architecture/secrets.md)                             | every key, its shape, and the build-time check      |
| [Network and the tailnet](docs/src/architecture/network.md)             | one open port, Tailscale, MagicDNS, Syncthing       |
| [The laptop as a third monitor](docs/src/architecture/third-monitor.md) | Sunshine, Moonlight, and the disconnect watcher     |
| [Installing a machine](docs/src/operations/installing.md)               | `install.sh`, step by step, and new hardware        |
| [Rebuilding and deploying](docs/src/operations/deploying.md)            | `nixos-rebuild` and deploy-rs over Tailscale        |
| [Known hazards](docs/src/operations/hazards.md)                         | what will hurt if forgotten                         |

Those links go to the source, which renders in Forgejo, diagrams included.

## Quick start

| Command                                                                          | Does                                                 |
| -------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `sudo nixos-rebuild switch --flake .#hutao-desktop`                              | rebuild the machine you are at                       |
| `nix develop -c deploy .#hutao-laptop`                                           | deploy to the laptop over Tailscale, with rollback   |
| `nix run .#vm`                                                                   | boot the desktop layer in QEMU (`hutao` / `vm`)      |
| `nix develop -c pre-commit run --all-files`                                      | lint, exactly as CI does                             |
| `SOPS_AGE_KEY_FILE=~/.sops-nix/key.txt nix develop -c sops secrets/secrets.yaml` | edit the secrets                                     |
| `nix build .#installer-iso`                                                      | build the installer ISO                              |
| `vm/install-test.sh all`                                                         | rehearse a full install against a blank virtual disk |
| `nix run .#docs`                                                                 | serve the handbook with live reload                  |

Every key `modules/sops.nix` declares must be in `secrets/secrets.yaml` before
anything builds; `install.sh` checks the full list before it touches a disk.
See [Secrets](docs/src/architecture/secrets.md).
