# ==============================================================================
# Neovim, and the toolchain mason cannot provide
# ==============================================================================
# mason.nvim does not work on NixOS and cannot be made to. It downloads
# pre-built, dynamically-linked binaries that expect
# /lib64/ld-linux-x86-64.so.2 and an FHS layout; neither exists here, so the
# install reports success and every server then fails to exec. With ~25
# lazyvim lang extras enabled that is a lot of quietly broken tooling.
#
# The fix is not to patch mason but to stop needing it: nvim-config detects
# NixOS at runtime (lua/utils/nix.lua) and skips mason-tool-installer, and
# every server is resolved from PATH instead — which is what this file fills.
#
# ── Drift ────────────────────────────────────────────────────────────────────
#
# This list mirrors two tables in the nvim-config repo:
#
#   lua/plugins/lspconfig.lua   the `servers` table
#   lua/plugins/conform.lua     `formatters_by_ft`
#
# Adding a server there without adding its package here gives you an LSP that
# silently never attaches. The config fails soft on purpose — it only enables
# servers whose binary is actually on PATH — so the symptom is absence, not an
# error, which is exactly the kind of thing that goes unnoticed for weeks.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    neovim
    neovide

    # ── Language servers ────────────────────────────────────────────────────
    clang-tools # clangd, and clang-format below
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

    # ── Formatters ──────────────────────────────────────────────────────────
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
    # nixfmt — the rfc-style one; the attribute dropped its suffix, and
    # nixfmt-rfc-style is now an alias that warns. Matches this repo's own
    # pre-commit hook, so the editor and CI agree on nix formatting.
    #
    # conform.lua used to call nixpkgs-fmt, which is deprecated upstream and
    # gone from recent nixpkgs — and it was declared as a formatter definition
    # inside formatters_by_ft, so nix files matched nothing and were never
    # formatted at all. Both fixed on the nvim-config side.
    nixfmt
    # gofmt ships inside the go distribution rather than separately.
    go

    # ── treesitter ──────────────────────────────────────────────────────────
    # nvim-treesitter compiles parsers on demand, so it needs a compiler and
    # the CLI at runtime. clang and nodejs are already in modules/desktop.nix;
    # the tree-sitter CLI is not, and `:TSUpdate` fails without it.
    tree-sitter
  ];
}
