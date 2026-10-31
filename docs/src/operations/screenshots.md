# Screenshots and recording

HyprCapture handles desktop screenshots and recording. Its compositor plugin
and Qt helper come from one package, registered by `hypr/modules/capture.lua`
before the keybindings. The plugin path is substituted by `home/apps/dotfiles.nix`.
Hyprshot, Grim, Slurp and Swappy are no longer installed by the screenshot
configuration; the old screenshot wrappers are excluded from the `cli-utils`
bundle's inputs as well.

Caelestia's picker IPC and screenshot global shortcuts also delegate to
HyprCapture, including clipboard-only variants. `caelestia screenshot` captures
the current monitor; `caelestia screenshot -r` opens HyprCapture's selection
and editor. Legacy explicit region geometry opens interactive selection too.
Freeze flags need no separate backend because HyprCapture freezes selection.
The replacements live in `pkgs/caelestia-hyprcapture-*` and are installed by
`home/apps/caelestia.nix`. Its separate recording command still uses Slurp;
the new Alt+Print recording shortcut uses HyprCapture.

## Shortcuts

| Shortcut         | Action                                                          |
| ---------------- | --------------------------------------------------------------- |
| Super+S or Print | Open capture selection, then the annotation editor              |
| Super+Shift+S    | Immediately capture the current monitor                         |
| Ctrl+Alt+S       | Immediately capture the focused window                          |
| Alt+Print        | Open recording selection, or stop an active recording           |
| Super+T          | Extract text from the clipboard image, choosing an OCR language |
| Super+Shift+T    | Extract English text from the clipboard image                   |

For OCR, capture with HyprCapture first, then use one of the text extraction
shortcuts. `screenshot-ocr` in `home/apps/hyprland.nix` runs Tesseract on the
clipboard PNG and replaces it with recognized text. Cancellation, no image or
no detected text leaves the clipboard unchanged. OCR does not start a second
capture tool.

The selection overlay uses fusion mode: drag to select a region, click a
window, or use the toolbar for a fullscreen capture. Escape cancels. Window
screenshots retain transparency, borders and shadows. The shadow's bounds
provide space around a decorated window; an actual fullscreen window is
captured at its content bounds without compositor decorations. A PNG retains
translucency but cannot blur a background it is later placed over.

Screenshots save to `$XDG_PICTURES_DIR/Screenshots` (normally
`~/Pictures/Screenshots`) and copy to the clipboard. Recordings save to
`$XDG_VIDEOS_DIR/Screenrecords`. A floating result thumbnail provides open,
copy, save and file actions. Transparent window recording uses an
alpha-capable format (WebM by default).

`pkgs/hyprcapture-focused-window.patch` makes quick window capture follow
keyboard focus rather than the pointer. Interactive window selection is
unchanged. `pkgs/hyprcapture.nix` applies it to the upstream package.

## Updating the compositor and plugin

`flake.nix` pins Hyprland to a release tag and locks HyprCapture, whose Hyprland
input follows the same input. `modules/desktop/hyprland.nix` selects that
compositor and its matching portal, independently of the system's nixpkgs
revision. It also enables Hyprland's official Cachix binary cache. The
wallpaper pause service uses this compositor's `hyprctl` too.

When upgrading, choose a Hyprland release supported by HyprCapture, edit the
release tag, then update and build both together:

```sh
nix flake update hyprland hyprcapture
nix develop -c pre-commit run --all-files
sudo nixos-rebuild switch --flake .#hutao-desktop
```

Log out and back in after changing Hyprland. A rebuild changes the installed
binary but leaves the running compositor on the old revision, which cannot
load a plugin built against the new revision. The capture module skips loading
on a different running release and applies settings only once the plugin API
is available. Until then, the capture shortcuts display a session restart
reminder. The rebuild does not log you out. After the new login, check
`hyprctl plugin list` and `hyprctl configerrors`.
