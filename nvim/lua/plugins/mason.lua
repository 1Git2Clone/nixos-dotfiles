-- Mason is off on NixOS. Its packages are prebuilt binaries that want
-- /lib64/ld-linux-x86-64.so.2, so they install and then cannot exec, and it
-- prepends its own bin/ to nvim's PATH -- which shadowed the working servers
-- from modules/neovim.nix with dead ones. gopls was worse than dead: it has no
-- prebuilt, so mason ran `go install` on every start, pulled the module graph
-- and failed on a gcc that is not there either, freezing the UI on the first
-- file opened.
--
-- modules/neovim.nix provides every server, formatter and linter this config
-- names, so nothing here needs an installer. Kept as disabled specs rather
-- than deleted: LazyVim's own lspconfig spec lists them as dependencies, and
-- lazy.nvim needs to see the `enabled = false` to drop them from it.

---@module "lazy"
---@type LazySpec
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "WhoIsSethDaniel/mason-tool-installer.nvim", enabled = false },
}
