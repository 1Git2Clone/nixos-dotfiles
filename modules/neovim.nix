# The toolchain mason cannot install: its prebuilt binaries want
# /lib64/ld-linux-x86-64.so.2, so they install then fail to exec.
#
# Mirrors nvim-config's lspconfig `servers` and conform `formatters_by_ft`.
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

    # :TSUpdate compiles parsers on demand. clang and nodejs are in desktop.nix.
    tree-sitter
  ];
}
