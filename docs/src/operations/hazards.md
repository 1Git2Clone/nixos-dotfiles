# Known hazards

Things that are not bugs today but will hurt if forgotten.

## One LUKS keyslot, no recovery key

Lose `luks_passphrase` and the disk is gone: there is no second slot and no
escrow. LUKS2 has eight slots, so adding a second passphrase after first boot is
cheap insurance:

```bash
sudo cryptsetup luksAddKey /dev/disk/by-partlabel/<the cryptroot partition>
```

Rotating is `cryptsetup luksChangeKey`. Both are imperative, which is why
neither lives in a module.

## Every declared secret is required

A key declared in `modules/sops.nix` but missing from `secrets/secrets.yaml`
fails the build, on every host, so adding a declaration means adding the value
in the same change. `install.sh` checks the full list before touching a disk;
see [Secrets](../architecture/secrets.md).

## Suspend and resume on the laptop

The known hazard on that hardware. It was fixed by DMI quirks in Linux 6.6, so
the current kernel is fine, but start there if it misbehaves.

## Tailscale auth key expiry

A used-up or expired `tailscale_authkey` fails `tailscaled-autoconnect` at boot
without blocking anything else. It only matters for a fresh install or a node
that has been removed from the tailnet; `systemctl status tailscaled-autoconnect`
says so.

## The invisible monitor

If the Sunshine disconnect watcher ever stops matching Sunshine's log line, a
disconnected laptop leaves `LAPTOP` behind right of DP-1 and the pointer can get
lost on it. `hyprctl output remove LAPTOP` clears it. See
[The laptop as a third monitor](../architecture/third-monitor.md#the-disconnect-watcher).

## Third-party art is not ours to publish

The cursor packs (including Hutao-Cursor, EbiEbiBeam's artwork: free but not
redistributable), the Hutao-Folders icons, the wallpapers and the greeter
background live in the private `third-party-assets` repo, not here, and were
filtered out of this repo's history when they moved. That is why CI evaluates
only the installer, and why the real machines need a Forgejo token to build.
Keep it that way: this repo is public, so new art goes in that repo and is
read from the input.

## A credential section starts with an empty helper

`dot-gitconfig`'s `[credential]` sets `helper = cache --timeout=3600` for every
host, and git asks every helper in the list, that one first. A host section
that adds its own helper (GCM for `git.hu-tao.dev`, `gh` for GitHub) has to
start with an empty `helper =` to drop the cache, or the cache hands back an
expired token: the first push fails, git erases it, and only the retry reaches
the real helper. Learned 2026-09-30, from Forgejo pushes that always failed
once.
