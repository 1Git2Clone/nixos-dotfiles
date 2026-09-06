# The toolchain mason cannot install: its prebuilt binaries want
# /lib64/ld-linux-x86-64.so.2, so they install then fail to exec.
#
# Mirrors lspconfig.lua's `servers` and conform's `formatters_by_ft`.
# lspconfig only enables what is on PATH, so a server missing here silently
# never attaches.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    neovim
    neovide

    # Language servers
    clang-tools
    lua-language-server
    typescript-language-server
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

    # :TSUpdate compiles parsers on demand. clang and nodejs are in desktop.nix.
    tree-sitter
  ];
}
