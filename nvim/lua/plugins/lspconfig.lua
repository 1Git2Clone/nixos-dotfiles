local nix = require("utils.nix")

---@module "lazy"
---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "j-hui/fidget.nvim",
    },
    config = function()
      local mason_installer = require("mason-tool-installer")

      local servers = {
        clangd = {},
        lua_ls = {
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              workspace = {
                checkThirdParty = false,
                library = {
                  vim.env.VIMRUNTIME,
                },
              },
              completion = { callSnippet = "Replace" },
              telemetry = { enabled = false },
            },
          },
        },
        ts_ls = {},
        rust_analyzer = {},
        phpactor = {},
        gopls = {},
        bashls = {},
        dockerls = {},
        yamlls = {},
        jsonls = {},
        texlab = {},
        pyright = {},
        jedi_language_server = {},
        nixd = {
          cmd = { "nixd" },
          settings = {
            nixd = {
              nixpkgs = {
                expr = "import <nixpkgs> { }",
              },
              options = {
                nixos = {
                  expr = nix.get_nixos_expr(),
                },
              },
            },
          },
        },
      }
      local mason_servers = vim.tbl_filter(function(name)
        return name ~= "nixd"
      end, vim.tbl_keys(servers))

      mason_installer.setup({
        ensure_installed = mason_servers,
      })

      for name, opts in pairs(servers) do
        vim.lsp.config(name, opts or {})
      end

      for name in pairs(servers) do
        vim.lsp.enable(name)
      end
    end,
  },
}
