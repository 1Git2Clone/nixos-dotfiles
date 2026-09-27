# The user layer

`home/` replays `stow --dotfiles` without stow. It walks `dotfiles/`, honours
`dotfiles/.stow-local-ignore`, renames `dot-foo` to `.foo`, and symlinks the
result out of the store. Nothing is listed by hand, so a new dotfile needs no
edit here. Each app that needs more than a link has its own file under
`home/apps/`.

## On top of the plain tree

`home/apps/dotfiles.nix` builds the tree as one derivation and changes it in
five ways.

**NixOS patches**, each a `substituteInPlace --replace-fail`, so a patch that
upstream makes unnecessary is a failed build rather than a silent no-op:

| File                         | Patch                                                                  |
| ---------------------------- | ---------------------------------------------------------------------- |
| `dot-profile.d/utils.sh`     | `/usr/bin/nvim` → `command nvim`                                       |
| `hypr/modules/programs.lua`  | the hard-coded FHS `XDG_DATA_DIRS` that empties every launcher         |
| `hypr/modules/autostart.lua` | the `/usr/lib` polkit and geoclue agent paths                          |
| `dot-gitconfig`              | `/usr/bin/gh` → the store's `gh`; gpg credential store → secretservice |
| `dot-tmux.conf`              | the `/usr/share` resurrect and continuum plugin paths                  |
| `hypr/modules/programs.lua`  | cursor theme and size, from the system's stylix settings               |

**Path rewrites.** Configs that hard-coded `$HOME/dotfiles/...` under stow are
repointed by `repath` at the `~/.config`, `~/.local` and `~/.profile.d` the
walk already links, so nothing needs a second copy of the tree in `$HOME`.

**`monitors.lua`**, copied in from `hosts/<name>/`. `hyprland.lua` requires it,
and upstream gitignores it because it is per machine.

**The wallpapers**, copied into `dot-config/hypr/backgrounds/` from the private
`third-party-assets` input, since they are fan art this public repo cannot
carry. That is still the path hyprpaper, hyprlock and the caelestia seed read.

**Colours**, substituted with caelestia template fields rather than hex. Each
file with a colour in it becomes a caelestia template, and its path in `$HOME`
links to what caelestia renders from it, so the desktop recolours on a scheme
switch without a rebuild. See [Colours](colours.md).

## What stays writable

Symlinks into the store are read-only, so anything an app rewrites has to be
handled on purpose:

- `lazy-lock.json`, `lazyvim.json`, caelestia's active scheme and
  `~/Pictures/Wallpapers` are **seeded once** from the tracked copy and then
  left alone, so `:Lazy update` and `caelestia scheme set` keep working.
- The **colour-bearing configs** (kitty, waybar, mako, starship, …) link out
  of the store into `$XDG_STATE_HOME/caelestia/theme/`, which caelestia
  rewrites on every scheme switch and activation renders on every rebuild.
- `~/.config/nvim` and `~/.claude` are **linked entry by entry**, not whole, so
  lazy.nvim and Claude Code get a real directory to write into. Link nvim whole
  and lazy.nvim's first write fails, aborting `init.lua` on every first boot.
- **Spotify's `Apps`** is a writable copy in
  `~/.local/share/spotify-spicetify`, and spicetify's `config-xpui.ini` is
  edited rather than linked. See [Spotify and spicetify](#spotify-and-spicetify).
- Everything else in `~/.config` is read-only. An app that saves settings there
  (fcitx5 does) cannot. To hack on the dotfiles in place, point `src` in
  `home/` at `mkOutOfStoreSymlink`.

## Neovim

mason is disabled: its prebuilt binaries cannot run on NixOS, so
`home/apps/neovim.nix` provides the language servers instead. Add a server
there **and** to `nvim/lua/plugins/lspconfig.lua`'s `servers` table, or it never
attaches and nothing says so. `home/nvim-nixos.lua` silences the warnings
LazyVim's language extras raise for packages mason did not install.

## Hyprland reloads on rebuild

`home.activation.hyprlandReload` runs `hyprctl reload` and `hyprctl setcursor`
after home-manager links the new generation. Hyprland's own file watcher never
fires here: a rebuild points `~/.config/hypr` at a new store path rather than
changing the file the watcher holds, so without this an edit waits for the
next login.

## The shell restarts on rebuild

`home.activation.caelestiaReload` in `home/apps/caelestia.nix` kills the
shell (`caelestia shell -k`), because a running shell keeps icon lookups
cached from the profile it started with. It then has Hyprland start it again
over `hyprctl eval`, with `programs.shell` from
`hypr/modules/programs.lua`, the command `autostart.lua` runs too.

Learned the hard way on 2026-09-26: started from the activation service, the
shell inherits `QT_QPA_PLATFORM=offscreen`, finds no display, and exits,
leaving no shell until one is started by hand. The eval uses `dofile`, not
`require`, so it reads the new `programs.lua` rather than a module cached
from before the switch.

## Fonts

`hutao.uiFont` in `home/apps/fonts.nix` is the one switch for every UI's
font, by default stylix's monospace, JetBrainsMono Nerd Font. It reaches:

- GTK through `gtk.font`, and so Nautilus, Evolution, and the chrome of the
  browsers and LibreOffice;
- Qt through caelestia's qtengine template (`home/apps/caelestia.nix`), and
  so KTailctl;
- the caelestia shell through `programs.caelestia.settings.appearance.font`;
- Discord's `--font` and fcitx5's `classicui.conf`, both literals in the
  dotfiles that `home/apps/dotfiles.nix` substitutes (`refont`).

fontconfig's defaults stay stylix's `sansSerif` and `serif`, so web pages and
LibreOffice documents keep a proportional face: a document asking for Calibri
falls back to sans-serif, and that should not be a monospace.

## Spotify and spicetify

spicetify patches Spotify's `Apps` directory in place, and the store copy is
read-only. `home/apps/spicetify.nix` wraps `spotify` with
`--app-directory=~/.local/share/spotify-spicetify/Apps`, and spicetify's
`spotify_path` is that directory: the writable `Apps` plus a link to the one
store file spicetify reads, `v8_context_snapshot.bin`. The marketplace and
caelestia's `user.css` are pinned fetches, linked into `~/.config/spicetify`.

`home.activation.spicetify` re-copies `Apps` from the store, sets the config
and runs `spicetify backup apply` only when an input changes (the store paths
in `~/.local/share/spotify-spicetify/stamp`). It passes `-n`, so a running
Spotify picks the change up on its next start. spicetify refuses to apply
once prefs' `app.last-launched-version` stops matching the version the backup
was taken at, so activation writes the store's version there first, and a
mismatch makes it re-apply on the next rebuild.

Marketplace installs live in Spotify's own storage, not in the repo.

Two settings are Nix's, and the rest of Settings stays the GUI's. Activation
sets streaming and download quality to very high (`audio.*bitrate_enumeration=4`)
in each profile's `~/.config/spotify/Users/*/prefs`, touching only those keys.
"Show the now-playing panel on click of play" lives in Spotify's local
storage rather than a prefs file, so `home/spicetify-settings.js`, a
spicetify extension, turns it off on every launch.

## Not linted

`dotfiles/` is exempt from markdownlint, shellcheck and shfmt, because that
tree's own linter configs stayed in the repo it came from. The whitespace
fixers and gitleaks still cover it; see the closing note in
`.pre-commit-config.yaml`.
