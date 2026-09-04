# The single source of every colour in this configuration.
#
# The one file to edit is the scheme itself:
#   dotfiles/caelestia/schemes/hu-tao/default/dark.txt
#
# That file is caelestia's own format -- `key value`, 110 semantic keys -- and
# is kept canonical rather than mirrored so `caelestia scheme set hu-tao`
# keeps round-tripping. Everything else (stylix's base16 slots, the seeded
# scheme.json, kitty, waybar, mako, nvim, the greeter, ...) is derived from it
# at build time by this file, so a retune is one edit.
#
# No hex literal belongs here. A colour that is missing is a key to add to the
# scheme, not a constant to inline.
{ lib }:
let
  scheme = ./dotfiles/caelestia/schemes/hu-tao/default/dark.txt;

  # `key rrggbb` per line. The regex is the validator too: a typo'd or
  # short hex silently drops its key, and every consumer below indexes
  # `colours` by name, so the build fails on the missing attribute rather
  # than rendering a wrong colour.
  parse =
    text:
    builtins.listToAttrs (
      lib.concatMap (
        line:
        let
          m = builtins.match "([A-Za-z0-9_]+)[[:space:]]+#?([0-9a-fA-F]{6})[[:space:]]*" line;
        in
        lib.optional (m != null) {
          name = builtins.head m;
          value = lib.last m;
        }
      ) (lib.splitString "\n" (builtins.readFile text))
    );

  colours = parse scheme;
in
rec {
  inherit colours;

  # Bare `rrggbb`, `#rrggbb` and `0xrrggbb` of the same key, because the
  # consumers disagree about the prefix and nothing should be re-typing one.
  hex = lib.mapAttrs (_: v: "#${v}") colours;
  ox = lib.mapAttrs (_: v: "0x${v}") colours;

  # Hyprland and swaylock want the alpha appended, GTK/CSS wants rgba().
  argb = key: alpha: "${colours.${key}}${alpha}";
  rgba =
    key: alpha:
    let
      c = colours.${key};
      byte = i: toString (lib.fromHexString (builtins.substring i 2 c));
    in
    "rgba(${byte 0}, ${byte 2}, ${byte 4}, ${alpha})";

  # What caelestia writes to $XDG_STATE_HOME/caelestia/scheme.json, and what
  # the scheme directory's own name and path already say. `variant` is the
  # material generator preset the scheme was produced with; it is metadata,
  # not a colour, which is why it can live here.
  schemeJson = {
    name = "hu-tao";
    flavour = "default";
    mode = "dark";
    variant = "tonalspot";
    inherit colours;
  };

  # base16 for stylix. The mapping is the scheme's own semantics, not a
  # guess: base16's slot comments are in the comment column below.
  base16 = {
    system = "base16";
    name = "hu-tao";
    author = "hutao";
    variant = "dark";
    palette = {
      base00 = colours.base; # default background
      base01 = colours.surface0; # lighter background, status bars
      base02 = colours.surface1; # selection background
      base03 = colours.overlay2; # comments, invisibles
      base04 = colours.subtext1; # dark foreground
      base05 = colours.text; # default foreground
      base06 = colours.rosewater; # light foreground
      base07 = colours.term15; # light background
      base08 = colours.red; # variables, errors
      base09 = colours.peach; # integers, constants
      base0A = colours.yellow; # classes, search highlight
      base0B = colours.green; # strings
      base0C = colours.mauve; # support, escapes
      base0D = colours.primary; # functions, headings
      base0E = colours.maroon; # keywords
      base0F = colours.term5; # deprecated
    };
  };
}
