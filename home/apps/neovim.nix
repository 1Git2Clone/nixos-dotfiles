# The editor: the toolchain mason cannot install -- its prebuilt binaries
# want /lib64/ld-linux-x86-64.so.2, so they install then fail to exec -- and
# the config tree, recoloured off the scheme.
#
# A user's editor, so a user profile and not /run/current-system/sw. The
# package list mirrors lspconfig.lua's `servers` and conform's
# `formatters_by_ft`: lspconfig only enables what is on PATH, so a server
# missing here silently never attaches.
{
  pkgs,
  lib,
  config,
  palette,
  ...
}:
let
  inherit (palette) hex ramp;

  # The nine-step pink the nvim colourscheme overrides Catppuccin with. Its
  # own 1st, 5th and 9th steps were already scheme colours; the six between
  # them were literals, so the whole ladder is interpolated off those anchors
  # instead (palette.nix's `ramp`) and follows a retune.
  nvimRamp = ramp "flamingo" "mauve" 5 ++ lib.tail (ramp "mauve" "onSecondaryFixedVariant" 5);

  nvimSrc = ../../nvim;

  nvimConfig = pkgs.runCommandLocal "nvim-config-nixos" { } ''
    cp -r ${nvimSrc} $out
    chmod -R u+w $out
    cp ${../nvim-nixos.lua} $out/lua/plugins/nixos.lua

    # Two files hold every colour the config picks: utils/colors.lua for the
    # highlights it sets itself, catppuccin.lua for the ramp it overrides the
    # colourscheme's own greys with.
    substituteInPlace $out/lua/utils/colors.lua \
      --replace-fail '#110000' '${hex.base}' \
      --replace-fail '#ff5077' '${hex.primary}' \
      --replace-fail '#ff9999' '${hex.secondary}' \
      --replace-fail '#ffaa88' '${hex.onSecondaryContainer}' \
      --replace-fail '#ff003e' '${hex.red}' \
      --replace-fail '#da5876' '${hex.term5}' \
      --replace-fail '#ffb3c3' '${hex.primaryFixedDim}'

    substituteInPlace $out/lua/plugins/catppuccin.lua \
      ${lib.concatStringsSep " \\\n      " (
        lib.zipListsWith (from: to: "--replace-fail '${from}' '#${to}'") [
          "#f7c0c8"
          "#e6aab3"
          "#d4939d"
          "#c17c87"
          "#ab6670"
          "#965159"
          "#7f3e44"
          "#6a2f36"
          "#541f27"
        ] nvimRamp
      )}
  '';

  # Written by lazy.nvim; seeded once, then left alone.
  nvimState = [
    "lazy-lock.json"
    "lazyvim.json"
  ];

  # .zshrc's plugins= list, minus the ones oh-my-zsh already ships.
in
{
  home.packages = with pkgs; [
    neovim
    neovide

    # Language servers
    clang-tools
    lua-language-server
    typescript-language-server
    svelte-language-server
    tailwindcss-language-server
    rust-analyzer
    phpactor
    gopls
    bash-language-server
    dockerfile-language-server
    yaml-language-server
    vscode-langservers-extracted # jsonls, html, css, eslint
    texlab
    pyright
    python3Packages.jedi-language-server
    nixd
    marksman # markdown; the lang.markdown extra configures it and nothing provided it

    # Formatters
    stylua
    isort
    black
    prettier
    ormolu
    rustfmt
    shfmt
    taplo
    texlivePackages.latexindent
    php84Packages.php-cs-fixer
    nixfmt
    go # gofmt

    # VimTeX compiles with latexmk, and nothing here shipped a TeX engine.
    # Curated instead of texliveMedium: 530M against 2.7G.  A document that
    # wants another package adds it to this list (the error names the .sty),
    # or swap the whole thing for texliveMedium.
    (texlive.withPackages (
      ps: with ps; [
        scheme-basic
        xetex # the Cyrillic documents need it; fontspec cannot run under pdftex
        latexmk
        fontspec
        polyglossia
        hyphen-bulgarian
        geometry
        amsmath
        booktabs
        tools # array
        enumitem
        fancyvrb
        listings
        xcolor
        hyperref
        titlesec
        tcolorbox
        tikzfill # tcolorbox [most]
        pgf
        pdfcol
        environ
        trimspaces
        etoolbox
      ]
    ))

    # Linters, all of them run by nvim-lint on save. LazyVim's lang extras
    # name these in linters_by_ft and mason would fetch them; mason is off
    # here, so a missing one is an "Error running <tool>: ENOENT" on every
    # save of that filetype rather than anything quieter.
    markdownlint-cli2
    statix # also this repo's own pre-commit linter
    hadolint
    hlint
    golangci-lint
    php84Packages.php-codesniffer # phpcs

    # :TSUpdate compiles parsers on demand. clang and nodejs are in packages.nix.
    tree-sitter
  ];

  # nvimState is dropped here and seeded by an activation script further down.
  xdg.configFile = lib.mapAttrs' (
    name: _: lib.nameValuePair "nvim/${name}" { source = "${nvimConfig}/${name}"; }
  ) (lib.removeAttrs (builtins.readDir nvimSrc) nvimState);

  # lazy.nvim rewrites these, so they cannot be store symlinks.
  # vim.loader keys its bytecode cache on path + mtime + size, and catppuccin
  # compiles the whole theme into one .luac of its own. Every lua file here is
  # a store symlink with mtime pinned to 1970 and the recolour swaps hex for
  # hex of the same byte length, so all three parts of that key hold still
  # across a palette retune: nvim keeps serving bytecode compiled before the
  # scheme changed, which is why the greys stayed catppuccin's own. Dropped
  # wholesale rather than diffed -- it is derived data, nvim rebuilds it on
  # the next start, and the alternative is teaching two caches about the Nix
  # store.
  home.activation.nvimCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -rf ${config.xdg.cacheHome}/nvim/luac ${config.xdg.cacheHome}/nvim/catppuccin
  '';

  home.activation.nvimState = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n" (f: ''
      if [ ! -e "${config.xdg.configHome}/nvim/${f}" ]; then
        run mkdir -p "${config.xdg.configHome}/nvim"
        run install -m644 ${nvimConfig}/${f} "${config.xdg.configHome}/nvim/${f}"
      fi
    '') nvimState
  );
}
