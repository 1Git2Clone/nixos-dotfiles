local colors = require("utils.colors")

---@module 'lazy'
---@type LazySpec
return {
  "nvim-lualine/lualine.nvim",
  opts = function()
    -- A function, so lualine's own ColorScheme autocmd rebuilds it off the
    -- current scheme after a switch rather than keeping the first one.
    local function lualine_theme()
      -- auto derives itself from the loaded colourscheme once and require
      -- caches it, so it is dropped to re-derive from the new one.
      package.loaded["lualine.themes.auto"] = nil
      local theme = require("lualine.themes.auto")
      for _, mode in pairs({ "normal", "insert", "visual", "replace", "command", "inactive", "terminal" }) do
        theme[mode].a = colors.default_fg_bg
        theme[mode].b = colors.default_fg_bg
        theme[mode].c = colors.default_fg_bg
      end
      return theme
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
            color = function()
              return { fg = colors.hl_col, gui = "bold" }
            end,
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
