# Hosts and layers

Every configuration in `flake.nix` is a stack of the same layers, and the
layers are the answer to "where does this go". `desktopModules` goes into all
three configurations; `hosts/common` and the hardware modules (the
`nixos-hardware` profiles, disko and sops-nix) go only into the laptop and the
desktop, which is why `hutao-vm` boots without an install.

| Layer            | What it holds                                                                      | Who gets it           |
| ---------------- | ---------------------------------------------------------------------------------- | --------------------- |
| `desktopModules` | `modules/system.nix`, the desktop environment in `modules/desktop/`, and `home/`   | every configuration   |
| `hosts/common`   | bootloader, kernel, firmware, graphics, and every module that needs a real install | the two real machines |
| `hosts/<name>`   | hardware config, disk sizes, `monitors.lua`, and what is physically attached       | that machine          |

`modules/desktop/` is the desktop *environment* shared by every host. It is not
`hutao-desktop`, whatever the name suggests.

**New things go in a shared layer** unless they belong to one machine's
hardware. The two machines are meant to feel identical, so a package added to
one host is usually a package the other is missing.

## The machines

| Host            | Hardware                                                        |
| --------------- | --------------------------------------------------------------- |
| `hutao-laptop`  | Lenovo IdeaPad 1 15AMN7: Ryzen 3 7320U, Radeon 610M, 8 GB, NVMe |
| `hutao-desktop` | Ryzen 5 3600X, RX 5600 XT, 16 GB, NVMe + a 2 TB HDD             |
| `hutao-vm`      | the desktop layer under QEMU; see [The VM](../operations/vm.md) |

What only the desktop has, all in `hosts/hutao-desktop/default.nix`:

- **The HDD**, LUKS-encrypted ext4, unlocked in the initrd with the same
  prompt as the root disk and mounted `nofail`. It is deliberately not in
  `modules/disk-layout.nix`, so a reinstall cannot wipe it. NTFS support stays
  for removable media only.
- **The Brother DCP-1512E** on USB: CUPS with `brlaser`, a declared queue, and
  `brscan4` for the scanner.
- **Sunshine**, which streams a headless monitor to the laptop. See
  [The laptop as a third monitor](third-monitor.md).
- `teams-for-linux` and evolution with EWS, for work mail.

What only the laptop has is one quirk: `amdgpu` loads after the LUKS unlock
rather than in the initrd, because early KMS resets the console in the middle
of the passphrase prompt. It also carries `moonlight-qt`.

## The installer

`hosts/installer` is a fourth configuration that is not a desktop at all: the
ISO `install.sh` runs from. See [Installing a machine](../operations/installing.md).
