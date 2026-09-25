# Introduction

This is the flake behind two workstations: a laptop and a desktop running the
same NixOS on `nixos-unstable`, with LVM-on-LUKS disks, immutable users whose
passwords come from sops, Hyprland with the caelestia shell, and Limine.

The user layer lives here too. `dotfiles/` and `nvim/` are symlinked into
`$HOME` by home-manager, so there is no stow and no second repo to bump: a
config change and the system change it needs are one commit.

## The machines

| Machine         | What it is                                               |
| --------------- | -------------------------------------------------------- |
| `hutao-desktop` | Ryzen 5 3600X, RX 5600 XT; the main workstation          |
| `hutao-laptop`  | Ryzen 3 7320U; the same desktop, and a third monitor     |
| `vps`           | its own repo; on the tailnet, and publishes this book    |
| `hutao-vm`      | not a machine: the desktop layer under QEMU, for testing |

How they talk to each other, all over the tailnet:

| From                          | To          | What                                                              |
| ----------------------------- | ----------- | ----------------------------------------------------------------- |
| laptop                        | desktop     | Moonlight: the desktop streams its third monitor to the laptop    |
| desktop                       | laptop      | deploy-rs over Tailscale SSH                                      |
| desktop                       | vps         | deploy-rs over the VPS's own sshd on port 2222, from the vps repo |
| desktop, laptop, vps, a phone | one another | Syncthing, sharing `~/syncthing`                                  |

Both deploys run from the desktop because that is where you usually sit. deploy-rs builds locally and activates remotely, so any machine on the
tailnet with Nix can drive them. The desktop itself has no deploy node: it is
rebuilt in place. See [Rebuilding and deploying](operations/deploying.md).

`hutao-vm` boots the same desktop layer without an install, for testing
anything above the disk. See [Hosts and layers](architecture/hosts.md).

## Where to start

| If you want to                        | Read                                                           |
| ------------------------------------- | -------------------------------------------------------------- |
| know what every host gets, and why    | [Hosts and layers](architecture/hosts.md)                      |
| change a dotfile                      | [The user layer](architecture/user-layer.md)                   |
| change a colour                       | [Colours](architecture/colours.md)                             |
| add or rotate a secret                | [Secrets](architecture/secrets.md)                             |
| use the laptop as a screen            | [The laptop as a third monitor](architecture/third-monitor.md) |
| ship a change                         | [Rebuilding and deploying](operations/deploying.md)            |
| install a machine from nothing        | [Installing a machine](operations/installing.md)               |
| try a desktop change without a reboot | [The VM and the install rehearsal](operations/vm.md)           |
| know why a thing is the way it is     | the comment at the top of the module that does it              |

That last row is the real index. This book says where things are and how they
fit; the reasoning lives next to the code it constrains, where it cannot rot
separately from it.

## Conventions

- **A gotcha has a date** when it was learned the hard way, so a live
  constraint can be told from a superstition.
- **Diagrams are mermaid.** They render here, in the Forgejo web UI, and in a
  pull request that changes one.
