---@module "lazy"
---@type LazySpec[]
return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)
    end,
  },

  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = "mason-org/mason.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          -- Add packages here
        },
      })
    end,
  },
}
