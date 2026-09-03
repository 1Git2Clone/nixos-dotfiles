local colors = require("utils.colors")

---@module 'lazy'
---@type LazySpec
return {
  "nvim-lualine/lualine.nvim",
  opts = function()
    local lualine_theme = require("lualine.themes.auto")

    for _, mode in pairs({ "normal", "insert", "visual", "replace", "command", "inactive", "terminal" }) do
      lualine_theme[mode].a = colors.default_fg_bg
      lualine_theme[mode].b = colors.default_fg_bg
      lualine_theme[mode].c = colors.default_fg_bg
    end

    return {
      options = {
        theme = lualine_theme,
        component_separators = "",
        section_separators = "",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          "filename",
          {
            function()
              local reg = vim.fn.reg_recording()
              if reg == "" then
                return ""
              end
              return "recording @" .. reg
            end,
            color = { fg = colors.hl_col, gui = "bold" },
            padding = { left = 1 },
          },
        },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    }
  end,
}
