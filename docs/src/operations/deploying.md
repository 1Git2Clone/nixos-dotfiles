# Rebuilding and deploying

## At the machine

```bash
sudo nixos-rebuild switch --flake .#hutao-desktop
```

This is the everyday path and needs nothing else. `sudo` evaluates the flake as
root, which has no keyring, so private flake inputs authenticate through the
root-only git credential store `modules/sops.nix` renders; see
[Secrets](../architecture/secrets.md).

A rebuild reloads Hyprland for you (see
[The user layer](../architecture/user-layer.md#hyprland-reloads-on-rebuild)),
but it does not start user units that did not exist before. A new
`systemd.user.services` entry needs `systemctl --user start` once, or a new
login.

## To another machine, with rollback

`deploy.nodes` in `flake.nix` drives deploy-rs over Tailscale SSH. Today that
is `hutao-laptop`.

```bash
nix develop -c deploy .#hutao-laptop                  # build here, activate there
nix develop -c deploy --dry-activate .#hutao-laptop
```

- **`sshUser = "root"`** rather than sudo, so `security.sudo.wheelNeedsPassword`
  stays true and the credential is the tailnet ACL, revocable from the admin
  console instead of baked into the host.
- **`hostname`** is the MagicDNS name, so no address is pinned in the repo.
- **`magicRollback`** makes the target confirm itself over the tailnet after
  activating, and roll back if it cannot. That is the case that matters when the
  link you deploy over is the one you might break. `autoRollback` covers a
  failed activation.

It needs three things, each learned the hard way:

- **Nix on the deploying machine.** deploy-rs builds locally and activates
  remotely; a stock macOS shell cannot drive it.
- **MagicDNS on the deploying machine** (`tailscale set --accept-dns=true`, and
  on NixOS, `services.resolved`). Without it the copy step cannot resolve
  `hutao-laptop`. The tailnet IP works as a fallback.
- **A different machine.** A host cannot deploy to itself over Tailscale SSH:
  the connection goes over loopback, tailscaled never intercepts it, and it lands
  on real sshd, which `PermitRootLogin = "no"` refuses. Use `nixos-rebuild`
  locally.

Also keep the tailnet ACL from forcing an interactive SSH re-auth, or
`magicRollback`'s confirmation times out and rolls back a good activation.

**`nixos-rebuild --target-host` does not work** as `hutao`: only `root` is in
`nix.settings.trusted-users`, so the target rejects the unsigned paths built
here. Use deploy-rs, or rebuild on the machine itself.

## Updating inputs

```bash
nix flake update                       # everything
nix flake update third-party-assets    # just the private art repo
```

The cursor and folder-icon packs come from the private `third-party-assets`
input, so a new pack there is invisible until that input is updated.
