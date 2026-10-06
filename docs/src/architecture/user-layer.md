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

The config and the module that installs it live in
[nvim-config](https://git.hu-tao.dev/hutao/nvim-config), imported in
`home/default.nix` as `inputs.nvim-config.homeModules.default`. The paths
below are in that repo. A change there needs a push and
`nix flake update nvim-config` before a rebuild sees it; to try one first,
rebuild with `--override-input nvim-config git+file:///home/hutao/Projects/nvim-config`.

mason is disabled: its prebuilt binaries cannot run on NixOS, so
`nix/home.nix` provides the language servers instead. Add a server
there **and** to `nvim/lua/plugins/lspconfig.lua`'s `servers` table, or it never
attaches and nothing says so. `nix/nixos.lua` silences the warnings
LazyVim's language extras raise for packages mason did not install.

It also points markdown-preview.nvim (`<leader>cp`) at nixpkgs' build. The
lang.markdown extra's own build downloads a prebuilt server that cannot run
here either, and lazy.nvim's git checkout has no `node_modules` for the `node`
fallback, so the preview died on `Cannot find module 'tslib'` (2026-09-29).
nixpkgs ships the app with its modules built; it runs with the `node` from
`home/apps/packages.nix`. The store path goes in when `nix/home.nix`
copies the file, in place of `@markdownPreview@`.

The preview takes caelestia's colours: `nvim/lua/plugins/markdown-preview.lua`
writes `~/.local/state/markdown-preview.nvim.css`, the plugin's stock
`markdown.css` with its colour variables set from the scheme, at startup and
on every switch. An open preview shows a switch on its next reload.

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

## tmux comes back after a restart

`dot-tmux.conf` has resurrect save every session (continuum, every 15 minutes)
and restore it when the tmux server starts. A pane comes back by retyping a
command line, so two hooks keep the stateful ones honest, both scripts from
cli-utils:

- **Claude panes** reopen the exact conversation they held. Claude's
  `SessionStart` hook (`dot-claude/settings.json`) runs
  `tmux-claude-tag-pane.sh`, which tags the pane with the conversation ID as
  the `@claude-session` pane option.
  `tmux-resurrect-save-claude.sh`, the post-save hook, writes each tag under
  the pane's position to `$XDG_STATE_HOME/tmux-claude-sessions`.
  `tmux-resurrect-resume-claude.sh` restores the pane with
  `claude --resume <id>`, or the picker when the pane has no entry.
- **workmux's sidebar** is saved like any pane but comes back as an empty
  shell beside the fresh sidebar workmux opens.
  `tmux-resurrect-drop-sidebars.sh`, the post-restore hook, removes it.

cli-utils tests all three end to end (`checks.<system>.tmux`), on a private
tmux server. Its config copies this one's resurrect lines, so a change here
belongs there too.

Learned the hard way on 2026-10-03: `claude --continue` reopens the
directory's newest conversation, not the pane's, so every Claude pane in one
directory came back as the same unrelated conversation. The same day, the
sidebar hook turned out to have never worked: it looked for resurrect's save
under `$XDG_DATA_HOME`, while resurrect writes to `~/.tmux/resurrect`.

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

## Firefox and Floorp userChrome

Both come from home-manager's `programs.firefox` and `programs.floorp` in
`home/apps/packages.nix`, not `home.packages`, so one `userChrome` string
styles both (today: it hides the sidebar's `#sidebar-panel-header`).
home-manager then writes `profiles.ini`, `user.js` (which turns on
`toolkit.legacyUserProfileCustomizations.stylesheets`) and
`chrome/userChrome.css`. The first rebuild moves the old `profiles.ini` and
any `user.js` aside as `*.hm-bak`. Restart the browser to pick up a change.

- **The profile paths are the desktop's.** `iz7vhs3z.default` (Firefox) and
  `wozr4wdp.default` (Floorp) are the directories each browser made on
  hutao-desktop. On another machine, home-manager points `profiles.ini` at
  an empty directory of that name, and the old profile is still there but
  unused. Rename the old one to match, or set `path` per host.
- **Floorp's `configPath` is set.** home-manager's default is `~/.floorp`,
  but `floorp-bin` keeps its profiles in `~/.config/floorp`.

## Wallpaper Engine

`home/apps/wallpaper-engine.nix` plays Steam Workshop wallpapers with
nixpkgs' `linux-wallpaperengine`. The GUI is AzPepoze's
`linux-wallpaperengine-gui`, packaged in `pkgs/linux-wallpaperengine-gui.nix`
from its release AppImage, since upstream ships no other Linux build. Both
read their assets from the Steam install, so Wallpaper Engine (app 431960)
has to be owned and installed through Steam.

- **caelestia's wallpaper is the fallback.** caelestia draws it on the
  layer-shell Background layer, and the GUI starts the engine on Bottom (its
  `layer` setting, default `bottom`), which stacks above. A monitor with an
  engine wallpaper shows that one, and any other keeps caelestia's. Setting
  the GUI's layer to `background` would put the two on one layer, so leave it
  at `bottom`.
- **The colours still come from the static pick.** `caelestia wallpaper` and
  `current.json` drive the scheme, stylix, Limine and SDDM exactly as in
  [Colours](colours.md). The animated wallpaper feeds none of them.
- **A user service starts it at login.** It is bound to
  `graphical-session.target` and runs `linux-wallpaperengine-gui --minimized`:
  the Go backend sits in the tray and replays the last wallpaper, and opens
  the Electron window only on demand. The GUI's own autostart toggle writes
  an XDG autostart entry, which nothing here runs, so leave it off. The unit
  sets `XDG_SESSION_TYPE=wayland` itself: `autostart.lua` imports only
  `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP` and `HYPRLAND_INSTANCE_SIGNATURE`
  into systemd, and without it every engine start exited with "Cannot read
  environment variable XDG_SESSION_TYPE" (2026-10-06).
- **The package runs the backend, not the AppImage's entry.** That entry is
  Electron, which starts the backend and exits, and the FHS env takes the
  backend down with it.
- **What the backend shells out to is inside its FHS env:** the engine,
  `xrandr` for the screens (Xwayland's names match Hyprland's), `killall`,
  `xprop`, `zenity` for the folder picker and `notify-send`.
- **The wallpapers and some settings are Nix's.**
  `home.activation.wallpaperEngineSettings` merges them into
  `~/.config/linux-wallpaperengine-gui/config.json` on every rebuild:
  `screens`, a Workshop ID per output for both machines (`eDP-1`, the
  laptop's panel, shares `LAPTOP`'s), `steamPaths` (the GUI's defaults plus
  `/mnt/hdd/SteamLibrary`), `scaling = "fill"`, `fullscreenPauseOnlyActive`
  and `autostart = false`. The GUI only starts the screens that are
  connected, so one list serves both. `screens` is replaced whole, so a
  wallpaper picked in the GUI lasts until the next rebuild; change the IDs in
  `home/apps/wallpaper-engine.nix` to keep it. Filters, properties and the UI
  stay the GUI's. It rereads the file on every apply.
- **A fullscreen window freezes it.** The engine pauses while any window is
  fullscreen, on any workspace of any monitor, after drawing one frame: a
  scene stops still and a video stays black. `fullscreenPauseOnlyActive`
  narrows that to a focused fullscreen window, which is still a pause.
  Learned 2026-10-06 from a fullscreen Sober.

## Not linted

`dotfiles/` is exempt from markdownlint and shellcheck, because that tree's
own linter configs stayed in the repo it came from. The whitespace fixers,
gitleaks and shfmt still cover it; see the closing note in
`.pre-commit-config.yaml`. shfmt also checks `dot-bashrc`, `dot-zshrc` and
`dot-profile`, which have no `.sh` to match on, and skips the vendored
opencode skills.

Indentation is 2 spaces everywhere, set as the `.editorconfig` default;
Rust and Java are the exceptions at 4. Editors and shfmt both read it, and
conform.nvim runs shfmt on zsh files on save, so a shell dotfile that no
section matches gets shfmt's default of tabs.
