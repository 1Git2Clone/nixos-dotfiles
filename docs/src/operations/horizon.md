# Horizon Minecraft client

`home/apps/horizon.nix` installs **Horizon Minecraft 26.3** in the desktop
application menu. `horizon-launcher` opens the same launcher; `horizon-prepare`
and `horizon-ctl` expose the bundled preparation and control tools.
Prism Launcher remains installed and its instances are separate.

## First launch and connecting

1. Open **Horizon Minecraft 26.3**, or run `horizon-launcher`.
2. Sign in with a Microsoft account that owns Minecraft: Java Edition. Complete
   the device-code sign-in in your browser. Prism's accounts are not imported.
3. Press Play. If preparation is needed, the launcher can use an existing 26.3
   installation or download it from Mojang for the signed-in owner.
4. In Multiplayer, add `horizon.hu-tao.dev`. The server must allow your signed-in
   Minecraft profile on its whitelist; its deployment is maintained in the VPS
   repo. Select the Microsoft profile when joining an online-mode server.

To prepare explicitly from an existing Prism install:

```sh
horizon-launcher prepare --minecraft "$HOME/.local/share/PrismLauncher" \
  --version nightly-2026-10-30
```

Preparation reads the owned client jar, libraries and assets. It obtains the
pinned version metadata and server jar from Mojang, checks the game files
against `research-lock.json`, and runs the bundled exporters with Java 25.
Sounds are copied from the owned asset store too. Existing Prism packs and
worlds are not imported by this configuration.

## What is declarative

`pkgs/horizon/default.nix` fetches upstream Linux x86-64 binary archives with
fixed SHA-256 hashes: game **nightly-2026-10-30**, source commit
`587f81f9c69629e999584f30aae0c9edacfc1b1d`, and launcher **0.2.29**.
No Rust compilation is needed. `nix build .#horizon` builds this package alone.
The FHS wrapper supplies the graphics, audio, windowing and keyring libraries,
Java 25 and the helper programs needed by the launcher and its child processes.

The wrapper uses these folders below `${XDG_DATA_HOME:-$HOME/.local/share}`:

| Folder | Contents |
| --- | --- |
| `horizon-launcher-nixos/` | Launcher settings, accounts metadata, installed game binaries and preparation |
| `horizon-nixos/` | Horizon's own saves, options and logs |

On startup it copies the pinned upstream game files into the launcher's version
folder if the Nix source changed, selects that release, disables automatic game
installation and pruning, and disables launcher self-updates. Other launcher
settings are preserved. Nix supplies the menu entry, so upstream's menu-entry
creation is disabled. Update the package and rebuild to change the managed
versions; the version selection is restored on the next wrapper invocation.

Prepared Minecraft resources live privately under
`horizon-launcher-nixos/versions/nightly-2026-10-30/.local/horizon-client/26.3/`.
They, the imported jars, and account/session credentials must stay outside Git
and the Nix store. The launcher stores credentials through the desktop's secret
service; do not copy accounts or sessions to the server.

## Updates and authentication

Bump the game release and archive hash together, coordinate the same game
release with the VPS server, and update the version in this chapter. The
launcher has its own version and hash. Upstream publishes `SHA256SUMS` beside
both releases. There is no moving `nightly` URL in this package.

Verified 2026-10-31: the pinned game source implements session authentication
for online-mode servers, and launcher 0.2.29's release binary contains an Azure
application ID accepted by Microsoft's device-code endpoint. The pinned
`docs/hosting.md` still claims authentication is unavailable; that contradicts
its implementation and `docs/microsoft-account.md`. A successful device-code
request alone does not verify Mojang app approval or a complete account login;
those require the user's sign-in. Do not disable server authentication to work
around that stale document.

Upstream references:

- [Game release](https://github.com/horizon-rust/horizon/releases/tag/nightly-2026-10-30)
- [Launcher release](https://github.com/horizon-rust/horizon/releases/tag/launcher%400.2.29)
- [Pinned authentication design](https://github.com/horizon-rust/horizon/blob/587f81f9c69629e999584f30aae0c9edacfc1b1d/docs/microsoft-account.md)
- [Install guide](https://playhorizon.dev/docs/install)
