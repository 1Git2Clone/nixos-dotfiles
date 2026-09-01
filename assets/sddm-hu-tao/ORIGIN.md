# Where this came from

Vendored from [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme)
by keyitdev, **GPL-3.0-or-later** — see `LICENSE`, which is kept verbatim and
must stay.

Pinned at the revision nixpkgs packaged as `sddm-astronaut`
`0-unstable-2026-07-06`:

```text
292c87b770ff9eab1903dd2c6ddff466faf87fb0
```

## Why vendored rather than `pkgs.sddm-astronaut`

The upstream package is 22 MB, almost all of it wallpapers and fonts for the
nine themes we do not use. It also has no supported way to point a theme at
your own background: `Themes/*.conf` are files inside the store path, so
changing one means an overlay that rewrites a file in someone else's
derivation and re-downloads 22 MB to change one line.

Vendoring the ~90 KB actually needed makes the background a tracked file you
can swap by dropping a new PNG in `Backgrounds/` and changing one line in
`Themes/hu-tao.conf`.

## What was taken

| Kept | Why |
| --- | --- |
| `Main.qml` | the greeter |
| `Components/*.qml` | 7 files it imports |
| `Assets/*.svg` | the icons those reference |
| `LICENSE` | GPL obligation |
| `Themes/hu-tao.conf` | a copy of `pixel_sakura.conf`, see below |

Dropped: `Backgrounds/` (15 MB of other themes' wallpapers), `Fonts/` (3 MB —
we use the system JetBrainsMono Nerd Font), `Previews/` (792 KB), the other
nine `Themes/*.conf`, `setup.sh` and upstream's `README.md`.

## What was changed

`Themes/hu-tao.conf` is `pixel_sakura.conf` with exactly two lines different:

```diff
-Font="arcadeclassic"
+Font="JetBrainsMono Nerd Font"
-Background="Backgrounds/pixel_sakura.gif"
+Background="Backgrounds/hu-tao.png"
```

Everything else — the blue-grey `#3d495b` palette, `FormPosition="center"`,
`CropBackground="true"`, the hidden system buttons — is upstream's
`pixel_sakura` untouched.

Two things worth knowing:

- **`CropBackground="true"` is the "cover" behaviour.** Upstream has no key
  called `Layout`; this is the one that crops to fill instead of letterboxing,
  i.e. CSS `background-size: cover`. It was already true in `pixel_sakura`.
- **The palette is sakura's, not hu-tao's.** `#3d495b` is a muted blue-grey,
  chosen against pink petals. Over a red-and-dark Hu Tao image it may read as
  a clash. Changing it is a matter of editing the `Colors` block; it was left
  alone because "pixel sakura with this picture" is what was asked for.

`metadata.desktop` drops upstream's `Screenshot=` and `TranslationsDirectory=`
lines: the first pointed into `Previews/`, which is not vendored, and the
second named a `translations` directory that does not exist upstream either.

## Fonts

`Font=` takes a family name and the theme exposes no weight option, so this
renders JetBrainsMono Nerd Font **Regular**.

There is no Thin in this family. The available styles are ExtraLight, Light,
Regular, Medium, Bold, ExtraBold (plus italics). `Font="JetBrainsMono Nerd
Font ExtraLight"` is the closest thing to thin, but relies on fontconfig
resolving a family-plus-style string rather than a real family, so it is not
the default here.
