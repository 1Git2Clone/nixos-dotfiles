# app-icons

Placeholder icons for the hand-written entries in `~/.local/share/applications`
(`Fantasy Anime Game`, `Starry Railway Game`, `Triple Z`). Those name icons that
exist nowhere on the system, so the launcher drew Papirus' magenta
`image-missing` instead.

`home/hutao.nix` installs each file into `~/.local/share/icons/hicolor/scalable/apps/`
under the exact `Icon=` name, so normal icon-theme lookup finds it. The
`.desktop` files themselves are untouched.

To change an icon, replace the file — same name, `.svg` or `.png` — and rebuild.

Seeded from papirus-icon-theme's `applications-games` (GPL-3.0), which is a
sensible generic default until you drop in real artwork.
