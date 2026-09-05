local nix = require("utils.nix")

---@module "lazy"
---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "j-hui/fidget.nvim",
    },
    config = function()
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
      for name, opts in pairs(servers) do
        vim.lsp.config(name, opts or {})
      end

      for name in pairs(servers) do
        vim.lsp.enable(name)
      end
    end,
  },
}
