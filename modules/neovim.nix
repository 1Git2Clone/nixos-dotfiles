# Neovim plus the toolchain mason cannot install.
#
# mason downloads pre-built dynamically-linked binaries. NixOS has no
# /lib64/ld-linux-x86-64.so.2, so they install "successfully" then fail to
# exec. nvim-config detects NixOS and skips mason; these fill the gap.
#
# This list mirrors nvim-config's lspconfig.lua `servers` and conform.lua
# `formatters_by_ft`. Add a server there without adding it here and it silently
# never attaches — lspconfig.lua only enables what is on PATH.
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

    # nvim-treesitter compiles parsers on demand; :TSUpdate needs the CLI.
    # clang and nodejs come from modules/desktop.nix.
    tree-sitter
  ];
}
