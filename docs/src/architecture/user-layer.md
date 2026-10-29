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
| `dot-gitconfig`              | `/usr/bin/gh` → the store's `gh`                                       |
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
- **`~/.config/mimeapps.list`** is not managed: browsers and "Open with"
  write to it. Defaults the repo pins go in `xdg.mime.defaultApplications`
  (`/etc/xdg/mimeapps.list`), which the user file overrides per type. Folders
  open in Nautilus from there (`modules/desktop/portals.nix`); before that,
  kitty's `kitty-open.desktop` claimed `inode/directory`, so a file dialog's
  "open folder" launched a terminal. Learned 2026-10-25.
- Everything else in `~/.config` is read-only. An app that saves settings there
  (fcitx5 does) cannot. To hack on the dotfiles in place, point `src` in
  `home/` at `mkOutOfStoreSymlink`.

## Neovim

The config and the module that installs it live in
[nvim-config](https://git.hu-tao.dev/hutao/nvim-config), imported in
`home/default.nix` as `inputs.nvim-config.homeModules.default`. The paths
below are in that repo. A change there needs a push and
`nix flake update nvim-config` before a rebuild sees it; to try one first,
rebuild with `--override-input nvim-config git+file:///home/hutao/Projects/git.hu-tao.dev/hutao/nvim-config`.

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

## Music downloads land in the library

`yt-audio`, from cli-utils, downloads songs and playlists with yt-dlp and tags
them itself: separate artist values, album, date, and the thumbnail cropped to
a square cover. `dot-profile.d/exports.sh` sets `YT_AUDIO_ROOT` to
`~/syncthing/Music`, the folder the VPS's navidrome serves, so
`yt-audio <url>` from any directory writes `<album>/<title>.opus` or
`<playlist title>/<title>.opus` there. `-o` writes somewhere else instead.

Learned the hard way on 2026-10-22: an `LD_LIBRARY_PATH` that a dev shell
leaves behind, pointing at a newer alsa-lib, stops the ffmpeg in yt-audio's
wrapper from loading, and yt-dlp then says "ffprobe and ffmpeg not found".
Run it from a plain shell, or with `env -u LD_LIBRARY_PATH`.

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

`terminal-features` replaces tmux's defaults rather than adding to them, so
every feature the outer terminal should get is named there, `hyperlinks`
included. Without it tmux strips the OSC 8 links Claude Code prints. With
`mouse on`, Shift+click hands the click to kitty, which opens the link. A
change takes effect when a client attaches. Learned 2026-10-16.

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

## Claude Code ahead of nixpkgs

`pkgs/claude-code.nix` is nixpkgs' `claude-code` with only its release manifest
swapped (`.override { manifest = ...; }`), so the wrapper, patching and sandbox
deps stay nixpkgs'. It exists because the client only offers models in its own
catalog, so a model newer than nixpkgs' release is refused by `/model` until
nixpkgs bumps the package.

- **Bumping** is copying `version` and the per-platform `checksum`s from
  `https://downloads.claude.ai/claude-code-releases/<version>/manifest.zst.json`;
  `.../latest` names the newest version.
- **Delete it** once nixpkgs reaches the pinned version, and
  `home/apps/packages.nix` falls back to nixpkgs' package.

## Notifications for long commands and Claude

`pkgs/shell-notify.nix` packages `shell-notify`, which has four jobs:

- **`shell-notify send`**: `.zshrc` calls it after any command that ran
  `SHELL_NOTIFY_MIN` (30) seconds or more, unless its first word, after an
  optional `sudo`, is in `SHELL_NOTIFY_SKIP` (nvim, ssh, less, man, htop, tmux
  and the like). The title is `Shell <session>:<pane>`, or just `Shell` outside
  tmux. The body is the exit code, then one line from
  `deepseek/deepseek-v4.1-flash` on OpenRouter (`--model` or
  `SHELL_NOTIFY_MODEL` to change it), such as "[1] | System rebuild failed:
  unknown option programs.zsh.initExtraa". The model gets the command
  line, its exit code, and the first 20 and last 40 lines of its output, read
  back from the tmux pane. Outside tmux it gets no output. With no
  `OPENROUTER_API_KEY`, or no answer within 15 s, the body falls back to
  "Finished running <command>" or "Failed: <command>".
- **`shell-notify visible`**: exits 0 when the caller's terminal is on screen,
  meaning its tmux pane is the active one in an attached session and that
  client's window has Hyprland's focus. It exits 1 when it is not, and 2 when
  that cannot be told (Hyprland or the pane unreachable), and both `send` and
  Claude's `dot-claude/hooks/notify.sh` notify on anything but 0.
- **`shell-notify dismiss <pane>`**: closes the notifications sent from that
  pane once it is on screen by the same rule. Both `send` and Claude's hook
  send through `shell-notify notify`, which records each notification ID in
  `$XDG_RUNTIME_DIR/shell-notify/<pane number>`. tmux hooks in
  `dot-tmux.conf` (slot 50) call it when the terminal window gains focus
  (`client-focus-in`) and on session, window and pane switches. A running
  tmux server picks them up on `tmux source-file ~/.tmux.conf`.
- **A tmux server outlives Hyprland**: it keeps the signature it started
  with, so after a Hyprland restart every hook's `hyprctl` hit a dead socket
  and `dismiss` returned 1 on each focus (learned 2026-10-22). Hyprland's
  autostart (`modules/autostart.lua`) now pushes its own
  `HYPRLAND_INSTANCE_SIGNATURE` into tmux's global environment.
- **`shell-notify watch`**: the same outside tmux, where no tmux hook sees the
  focus change. `notify` records a notification sent outside tmux as
  `pid-<id>`, listing the processes above its sender, the terminal window
  among them. The `shell-notify-watch` user service (`home/apps/shell-notify.nix`)
  follows Hyprland's event socket and closes those whose list holds the
  newly focused window's pid. It restarts if the socket drops.
- **Not `pane-focus-in`**: workmux sets its own `pane-focus-in` on each agent
  pane, and tmux runs the pane's hook instead of the global one, so Claude
  panes never dismissed. Learned 2026-10-16.
- **Failures are logged, not swallowed**: `journalctl --user -t shell-notify`.
  The hooks' stderr goes nowhere, and until 2026-10-16 a notification sent
  outside tmux was never recorded at all, so it could not be dismissed and
  nothing said so. Closing an ID caelestia no longer has succeeds, so a failed
  close is the daemon itself, and the ID is kept to retry. `tmux display`
  answers a pane that no longer exists with exit 0 and blank fields, so its
  answers are checked, not its exit code.

- **The terminal icon is copied into hicolor** by `pkgs/app-icons.nix`, like
  the others there. caelestia drew the Papirus name as the missing-icon
  squares. Learned 2026-10-15.
- **Reasoning is off in the request.** DeepSeek V4.1 Flash otherwise spends
  the whole 60-token budget thinking and returns an empty answer. Learned
  2026-10-15.

## PhotoCraft

`pkgs/photocraft.nix` wraps upstream's x86_64 Linux release tarball (a Rust
Photoshop clone, no nixpkgs package). The binary links only libc; winit and
wgpu `dlopen` Wayland, xkbcommon, GL and Vulkan at runtime, so they sit on the
rpath via `runtimeDependencies` rather than `buildInputs`. It is in
`home/apps/packages.nix`.

- **`zenity` is on its `PATH`.** File > Open fell back to a bare `zenity` and
  did nothing without one, though the portals were running. Learned
  2026-10-09. The "could not find these libraries" warning at start is its own
  FHS check and is harmless: the libraries are on the rpath.
- **Bumping** is the new `version` plus the tarball's hash; `SHA256SUMS.txt`
  on the release lists it.
- **Drag-and-drop from other windows is unavailable on Wayland** (upstream);
  `WAYLAND_DISPLAY= photocraft` runs it under XWayland to get it.

## WordCraft, GridCraft, DeckCraft, CADCraft

`pkgs/wordcraft.nix`, `gridcraft.nix`, `deckcraft.nix` and `cadcraft.nix` are
`photocraft.nix`'s siblings (a Word, Excel, PowerPoint and AutoCAD stand-in):
the same upstream, tarball layout and rpath treatment, none in nixpkgs. All
four are in `home/apps/packages.nix`. Each tarball also ships a `<name>-cli`,
which gets no wrapper. `deckcraft` additionally links `libasound`, so
`alsa-lib` is in its `buildInputs`.

- **Bumping** is the new `version` plus the tarball's hash, from the release's
  `SHA256SUMS.txt`.
- **Not verified on the desktop**: they build and the rpath is set, but the
  windows have not been opened yet.

## Show Me The Key

`showmethekey` puts the keys you press on screen, the Wayland stand-in for
screenkey. Wayland gives no client the keys typed into another, so its GUI
starts a helper through `pkexec` that reads `/dev/input` as root.

- **`hutao` is not in `input`, on purpose.** That group can read every input
  device, so any process running as the user could log every keystroke,
  passwords included, with no root at all. It was in `modules/users.nix`
  until 2026-10-07. Show Me The Key is why it matters: in `input` it skips
  `pkexec` and runs the helper as the user (`smtk-keys-emitter.c`), so the
  password prompt at start is the sign the group is gone.

- **It is a system package.** It is in `modules/desktop/packages.nix`, not
  `home/apps/packages.nix`, because polkit loads its action file only from
  the system profile. From a user profile, `pkexec` would use its generic
  action and ask for the password on every start, not once in a while.
- **The overlay is a window rule.** The key display is a normal GTK4 window,
  not a layer-shell surface. `showmethekey-overlay` in
  `hypr/modules/window_rules.lua` floats it, pins it to every workspace,
  keeps it from taking focus when it opens, and moves it to `1500, 20`, the
  top-right corner of a 1920-wide monitor at the app's 400px width. The rule
  matches the English title `Floating Window - Show Me The Key`, so it stops
  matching under another locale.
- **It is non-interactive by toggle, not by rule.** Double-tap Ctrl anywhere
  to flip "Clickable" (off passes clicks through) and Alt to flip "Pause".
  The helper reads every key, so neither needs the window focused.
- **Its settings are Nix's.** `home/apps/showmethekey.nix` writes the ones
  that differ from the defaults (compact mode, Shift folded into the combo,
  no key borders, a 400×66.6 window, margin ratio 0.32, keys cleared after
  2000 ms idle) to dconf on every rebuild, so a change made in the GUI lasts
  until the next one. The schema stores the sizes and the timeout as
  doubles, so they are float literals: an integer would be written as an
  int32 and ignored. The on, Clickable and Pause switches are runtime state
  and left out. The text is 72% of the key area's height; there is no font
  size setting.
- **Borders are off for the punctuation.** A bordered key is drawn by its
  glyph's ink box, aligned to the bottom, so `'` sits where a comma would.
  Without borders the text sits on its baseline.
- **A new size needs the key window reopened.** The key window takes its
  width and height when it is created, so after a rebuild that changes them,
  flip the GUI's main switch off and on (2026-10-07).
- **It sees passwords too.** Turn it off before typing a secret on a
  recording.

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
