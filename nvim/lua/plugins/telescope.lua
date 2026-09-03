-- In ~/.config/nvim/lua/plugins/telescope.lua
return {
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {},
    },
    config = function(_, opts)
      require("telescope").setup(opts)

      local colors = require("utils.colors")

      vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = colors.default_bg })
      vim.api.nvim_set_hl(0, "TelescopeBorder", colors.default_fg_bg)
      vim.api.nvim_set_hl(0, "TelescopePromptNormal", { bg = colors.default_bg })
      vim.api.nvim_set_hl(0, "TelescopePromptBorder", colors.default_fg_bg)
      vim.api.nvim_set_hl(0, "TelescopeResultsNormal", { bg = colors.default_bg })
      vim.api.nvim_set_hl(0, "TelescopeResultsBorder", colors.default_fg_bg)
      vim.api.nvim_set_hl(0, "TelescopePreviewNormal", { bg = colors.default_bg })
      vim.api.nvim_set_hl(0, "TelescopePreviewBorder", colors.default_fg_bg)
      vim.api.nvim_set_hl(0, "TelescopeMatching", { fg = colors.hl_col, bold = true })
    end,
  },
}
