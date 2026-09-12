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
        -- An extra declares its server through LazyVim's `opts.servers`, and
        -- the config function below replaces LazyVim's own -- the one that
        -- reads them. So lang.svelte and lang.tailwind got nothing until they
        -- were named here too; the same holds for every extra added later.
        svelte = {},
        tailwindcss = {},
        -- vscode-langservers-extracted ships these three beside jsonls.
        eslint = {},
        cssls = {},
        html = {},
        -- DELIBERATELY ABSENT. `lazyvim.plugins.extras.lang.rust` (enabled in
        -- lazyvim.json) installs rustaceanvim, which starts and owns the
        -- rust-analyzer client itself. LazyVim's extra sets
        -- `rust_analyzer = { enabled = false }` here for exactly that reason;
        -- listing it again overrides that back on, so TWO servers index the
        -- same crate graph. Symptom: paired `rust-analyzer:` / `rust_analyzer:`
        -- messages and `-32603 request handler panicked: failed to unify type
        -- owners`. Configure rust via rustaceanvim, not here.
        phpactor = {},
        gopls = {},
        bashls = {},
        dockerls = {},
        yamlls = {},
        jsonls = {},
        texlab = {},
        marksman = {},
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
