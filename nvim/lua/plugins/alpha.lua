local colors = require("utils.colors")

---@type LazySpec
return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "▄   █   ▄          ▄▄▄▄▀ ██   ████▄   ▄",
      "█   █    █      ▀▀▀ █    █ █  █   █  █ ",
      "██▀▀█ █   █         █    █▄▄█ █   █ █  ",
      "█   █ █   █        █     █  █ ▀████ █  ",
      "   █  █▄ ▄█       ▀         █          ",
      "  ▀    ▀▀▀                 █        ▀  ",
      "                          ▀            ",
    }

    vim.api.nvim_set_hl(0, "AlphaHeader", { fg = colors.default_fg })
    vim.api.nvim_set_hl(0, "AlphaButtons", colors.default_fg_bg)
    vim.api.nvim_set_hl(0, "AlphaFooter", { fg = colors.default_fg, italic = true })
    vim.api.nvim_set_hl(0, "AlphaShortcut", { fg = colors.default_fg, italic = true })

    dashboard.section.buttons.val = {
      dashboard.button("n", "  New file", ":ene <BAR> startinsert<CR>"),
      dashboard.button("f", "󰈞  Find file", ":lua require('snacks').picker.files()<CR>"),
      dashboard.button("g", "󰈬  Find text", ":lua require('snacks').picker.grep()<CR>"),
      dashboard.button("r", "  Recent files", ":lua require('snacks').picker.recent()<CR>"),
      dashboard.button("c", "  Config", ":e ~/.config/nvim/init.lua<CR>"),
      dashboard.button("x", "  Lazy Extras", ":LazyExtras<CR>"),
      dashboard.button("q", "󰅚  Quit Neovim", ":qa<CR>"),
    }

    alpha.setup(dashboard.config)
  end,
}
