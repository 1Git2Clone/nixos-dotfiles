---@module 'lazy'
---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      terminal = {
        enabled = true,
        win = {
          style = "terminal",
        },
      },
      bigfile = { enabled = true },
      quickfile = { enabled = true },
      notifier = {
        enabled = true,
        style = "fancy",
        ---@param win snacks.Win
      },
      statuscolumn = { enabled = true },
      words = { enabled = true },

      win = {
        ---@param win snacks.Win
        style = function(win)
          local colors = require("utils.colors")
          -- Force border colors for all snack windows
          win:winopt("border", { fg = colors.default_fg, bg = colors.default_bg })
          if win.opts.backdrop then
            win:winopt("backdrop", 100)
          end
        end,
      },
    },
    keys = {
      {
        "<leader>tt",
        function()
          Snacks.terminal.toggle()
        end,
        desc = "Toggle Terminal",
      },
      {
        "<C-/>",
        function()
          Snacks.terminal.toggle()
        end,
        desc = "Toggle Terminal",
        mode = { "n", "t" },
      },
      {
        "<leader>.",
        function()
          Snacks.scratch()
        end,
        desc = "Toggle Scratch Buffer",
      },
      {
        "<leader>un",
        function()
          Snacks.notifier.show_history()
        end,
        desc = "Notification History",
      },
    },
    config = function(_, opts)
      require("snacks").setup(opts)

      -- Force highlight groups after setup
      vim.defer_fn(function()
        local colors = require("utils.colors")
        vim.api.nvim_set_hl(0, "SnacksInputBorder", colors.default_fg_bg)
        vim.api.nvim_set_hl(0, "SnacksNotifierBorder", colors.default_fg_bg)
        vim.api.nvim_set_hl(0, "SnacksWinBorder", colors.default_fg_bg)
      end, 100)
    end,
  },
}
