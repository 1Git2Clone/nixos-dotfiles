# The single source of every colour in this configuration.
#
# Which scheme that is, is caelestia's call: dotfiles/caelestia/current.json
# records what was last picked in the shell, and caelestia-theme-hook
# rewrites it on every switch (see home/apps/caelestia.nix). This file reads
# the colours of that scheme:
#
#   dynamic   dotfiles/caelestia/dynamic.txt, the hook's copy of what
#             caelestia generated from the wallpaper
#   ours      dotfiles/caelestia/schemes/<name>/<flavour>/<mode>.txt
#   upstream  the same path in caelestia-cli's own data/schemes
#
# All three are caelestia's own format -- `key value`, 110 semantic keys. The
# desktop recolours itself at runtime off caelestia's templates; what is
# derived here is what only a rebuild can reach (stylix's base16 slots, SDDM,
# the seeded scheme.json) and the template placeholders themselves.
#
# No hex literal belongs here. A colour that is missing is a key to add to the
# scheme, not a constant to inline.
{ lib, inputs }:
let
  current = lib.importJSON ./dotfiles/caelestia/current.json;

  schemePath = "${current.name}/${current.flavour}/${current.mode}.txt";
  ours = ./dotfiles/caelestia/schemes + "/${schemePath}";
  upstream = "${inputs.caelestia-shell.inputs.caelestia-cli}/src/caelestia/data/schemes/${schemePath}";

  scheme =
    if current.name == "dynamic" then
      ./dotfiles/caelestia/dynamic.txt
    else if builtins.pathExists ours then
      ours
    else
      upstream;

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

  channels =
    c:
    map (i: lib.fromHexString (builtins.substring i 2 c)) [
      0
      2
      4
    ];

  render =
    rgb:
    lib.concatMapStrings (
      v:
      let
        byte = lib.toLower (lib.toHexString (lib.min 255 (lib.max 0 (builtins.floor (v + 0.5)))));
      in
      if builtins.stringLength byte == 1 then "0${byte}" else byte
    ) rgb;
in
rec {
  inherit colours;

  # Straight sRGB interpolation between two keys of the scheme. Here so the
  # ramps below stay a function of the palette: a config that needs nine
  # evenly spaced pinks gets them from its two endpoints rather than from
  # nine literals nobody will remember to retune.
  mix =
    a: b: t:
    render (lib.zipListsWith (x: y: x + (y - x) * t) (channels colours.${a}) (channels colours.${b}));

  # n colours from a to b inclusive. `1.0 *` because nix divides integers.
  # The asserts are the check on the arithmetic above: a ramp's ends are its
  # anchors by definition, and a float or fencepost slip there would
  # otherwise only show up as a slightly wrong pink in the middle.
  ramp =
    a: b: n:
    assert mix a b 0.0 == lib.toLower colours.${a};
    assert mix a b 1.0 == lib.toLower colours.${b};
    map (i: mix a b (1.0 * i / (n - 1))) (lib.range 0 (n - 1));

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

  # KDE's ini format is the odd one out: bare decimal channels, no prefix and
  # no parentheses. A hex string in a kdeglobals colour key parses as black.
  rgb =
    key:
    let
      c = colours.${key};
      byte = i: toString (lib.fromHexString (builtins.substring i 2 c));
    in
    "${byte 0},${byte 2},${byte 4}";

  inherit (current) mode;

  # The same helpers, as caelestia template fields instead of colours, for
  # files caelestia renders into $XDG_STATE_HOME/caelestia/theme on every
  # scheme switch. `hex` is caelestia's bare rrggbb.
  template =
    let
      field = key: form: "{{ ${key}.${form} }}";
      channels = key: "${field key "red"}, ${field key "green"}, ${field key "blue"}";
    in
    {
      colours = lib.mapAttrs (key: _: field key "hex") colours;
      hex = lib.mapAttrs (key: _: "#${field key "hex"}") colours;
      argb = key: alpha: "${field key "hex"}${alpha}";
      rgba = key: alpha: "rgba(${channels key}, ${alpha})";
      rgb = key: "${field key "red"},${field key "green"},${field key "blue"}";
    };

  # What caelestia writes to $XDG_STATE_HOME/caelestia/scheme.json, seeded
  # before caelestia has run once.
  schemeJson = current // {
    inherit colours;
  };

  # base16 for stylix. The mapping is the scheme's own semantics, not a
  # guess: base16's slot comments are in the comment column below.
  base16 = {
    system = "base16";
    inherit (current) name;
    author = "caelestia";
    variant = current.mode;
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
