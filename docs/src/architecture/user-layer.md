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

**Colours**, substituted from the one scheme. See [Colours](colours.md).

## What stays writable

Symlinks into the store are read-only, so anything an app rewrites has to be
handled on purpose:

- `lazy-lock.json`, `lazyvim.json`, caelestia's active scheme and
  `~/Pictures/Wallpapers` are **seeded once** from the tracked copy and then
  left alone, so `:Lazy update` and `caelestia scheme set` keep working.
- `~/.config/nvim` and `~/.claude` are **linked entry by entry**, not whole, so
  lazy.nvim and Claude Code get a real directory to write into. Link nvim whole
  and lazy.nvim's first write fails, aborting `init.lua` on every first boot.
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

## Not linted

`dotfiles/` is exempt from markdownlint, shellcheck and shfmt, because that
tree's own linter configs stayed in the repo it came from. The whitespace
fixers and gitleaks still cover it; see the closing note in
`.pre-commit-config.yaml`.
