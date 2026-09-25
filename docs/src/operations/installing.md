# Installing a machine

Needs UEFI, your age key on the machine, and **every** key in
`secrets/secrets.yaml` already authored. See [Secrets](../architecture/secrets.md).

```bash
nix build .#installer-iso
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Add your SSH key to `vm/authorized_keys` before building the ISO, or you cannot
reach the installer over the network. Boot it, then from your workstation:

```bash
scp ~/.sops-nix/key.txt nixos@<ip>:/tmp/age.key
ssh nixos@<ip>
```

## On a host this repo already knows

```bash
sudo -i
git clone https://git.hu-tao.dev/hutao/nixos-dotfiles && cd nixos-dotfiles
INSTALL_AGE_KEY=/tmp/age.key HOST=hutao-desktop ./install.sh
```

`install.sh` is about 120 lines of shell, and its order is the design:
everything that can refuse happens before anything is destroyed.

1. **Preflight**: root, UEFI, the tools, and that the age key is a real age key
   and a recipient in `.sops.yaml`. A non-recipient key installs cleanly and
   then cannot decrypt its own passwords.
2. **Secrets**: every key the host declares, read from the flake's own
   `config.sops.secrets` rather than a list in the script, plus
   `luks_passphrase`, all present and non-empty, and the two password hashes
   crypt(3) rather than digests. Checked before the disk gate, because
   sops-nix fails the build on a missing key and in an install that build is
   `nixos-install`, after disko has wiped the disk.
3. **Disk**: lists `/dev/disk/by-id/` paths and makes you type the disk's size
   back. Never `/dev/nvme0n1`: enumeration order is not stable, and disko wipes
   whatever the name resolves to.
4. **Pin**: writes that choice into `hosts/<host>/disk.nix`, asking first if the
   file names a different disk. disko reads the device out of the flake.
5. **Hardware**: `nixos-generate-config --no-filesystems`, since disko owns
   `fileSystems.*`. Before the eval, because the flake imports the result.
6. **Dry eval**: an eval error here costs a minute; the same error after disko
   costs the disk.
7. **disko, then `nixos-install`**, with the age key seeded to
   `/var/lib/sops-nix/key.txt` first, for the reason in step 2.

Nothing is prompted for and nothing is written back: every credential comes
out of `secrets/secrets.yaml`.

| Variable                 | Meaning                                                    |
| ------------------------ | ---------------------------------------------------------- |
| `HOST`                   | which `nixosConfigurations` entry (default `hutao-laptop`) |
| `INSTALL_AGE_KEY`        | path to the age private key copied in above                |
| `INSTALL_DISK`           | target disk, required when non-interactive                 |
| `INSTALL_NONINTERACTIVE` | skip both confirmations; what `vm/install-test.sh` sets    |

The disko CLI is `nix run .#disko`, this repo's pinned input, so the tool that
partitions is the same version as the module describing the layout.

## The disk layout

`modules/disk-layout.nix`, LVM-on-LUKS so one passphrase unlocks everything:

```text
p1  ESP 2G, unencrypted       -> /boot
p2  LUKS2 "cryptroot" -> LVM  -> vg "pool" -> swap / root / home
```

Sizes and the target device come from `hosts/<name>/disk.nix`. Only the OS disk
is described: disko describes what to *create*, and the desktop's HDD has to
survive a reinstall. There is one LUKS keyslot and no recovery key; see
[Known hazards](hazards.md).

## Why not disko-install or nixos-anywhere

`disko-install` would collapse steps 4 and 7 and the key seeding into one
command. But it runs disko with `DISKO_SKIP_SWAP=1`, and on the 8 GB laptop
`nixos-install` needs the swap LV that plain disko activates. Without it the
build runs out of memory deep into the install.

nixos-anywhere would replace the script outright, but it installs *to* a target
over SSH from a second machine. This runs on the machine being installed, from
its own ISO, which is what recovery assumes: the laptop is what you reach for
when something else is broken.

## On new hardware

Four files, then the same `install.sh`.

1. The hardware config, from the live environment, before disko.
   `--no-filesystems` because disko owns `fileSystems.*`:

   ```bash
   nixos-generate-config --no-filesystems --dir /tmp/hw
   mkdir -p hosts/<name>
   cp /tmp/hw/hardware-configuration.nix hosts/<name>/
   ```

2. Disk sizes and the target device:

   ```bash
   cp hosts/hutao-desktop/disk.nix hosts/<name>/
   ```

3. `hosts/<name>/monitors.lua`. `hyprland.lua` requires it, so an empty file is
   the minimum. Get real names from `hyprctl monitors all` and copy
   `hosts/hutao-desktop/monitors.lua` for the shape.
4. `hosts/<name>/default.nix`:

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
`nixos-hardware` profiles for the CPU and GPU you have, and add its Syncthing
device ID to `modules/syncthing.nix` after first boot.
