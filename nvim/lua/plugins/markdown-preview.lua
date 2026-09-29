-- markdown-preview.nvim (<leader>cp, from the lang.markdown extra) in
-- caelestia's colours. Its server reads g:mkdp_markdown_css on every page
-- load, and the file replaces the stock markdown.css outright, so it is the
-- stock one with its variables, and page.css's, set from the scheme. Written
-- at startup and on every scheme switch; an open preview picks it up on its
-- next reload.
local colors = require("utils.colors")

local css_path = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")) .. "/markdown-preview.nvim.css"

---@param stock string the plugin's own app/_static/markdown.css
local function write(stock)
  local s = colors.scheme
  if not s then
    vim.g.mkdp_markdown_css = ""
    return
  end
  local vars = {
    -- markdown.css
    ["color-text-primary"] = s.onSurface,
    ["color-text-tertiary"] = s.onSurfaceVariant,
    ["color-text-link"] = s.primary,
    ["color-bg-primary"] = s.surface,
    ["color-bg-secondary"] = s.surfaceContainerLow,
    ["color-bg-tertiary"] = s.surfaceContainer,
    ["color-border-primary"] = s.outlineVariant,
    ["color-border-secondary"] = s.outlineVariant,
    ["color-border-tertiary"] = s.outline,
    ["color-kbd-foreground"] = s.onSurfaceVariant,
    ["color-markdown-blockquote-border"] = s.primary,
    ["color-markdown-table-border"] = s.outlineVariant,
    ["color-markdown-table-tr-border"] = s.outlineVariant,
    ["color-markdown-code-bg"] = s.surfaceContainerHigh,
    -- page.css, around the document
    ["foreground-color"] = s.onSurface,
    ["background-color"] = s.surface,
    ["border-color"] = s.outlineVariant,
    ["secondary-background-color"] = s.background,
  }
  local lines = {}
  for name, value in vim.spairs(vars) do
    lines[#lines + 1] = ("  --%s: %s;"):format(name, value)
  end
  -- Both themes get the scheme: it is already light or dark. body because
  -- page.css sets --secondary-background-color there.
  local css = ("%s\n:root, body, [data-theme] {\n%s\n}\n"):format(stock, table.concat(lines, "\n"))
  local f = io.open(css_path, "w")
  if not f then
    return
  end
  f:write(css)
  f:close()
  vim.g.mkdp_markdown_css = css_path
end

---@module "lazy"
---@type LazySpec[]
return {
  {
    "iamcco/markdown-preview.nvim",
    optional = true,
    init = function(plugin)
      local f = io.open(plugin.dir .. "/app/_static/markdown.css", "r")
      if not f then
        return
      end
      local stock = f:read("*a")
      f:close()
      write(stock)
      colors.watch(function()
        colors.reload()
        write(stock)
      end)
    end,
  },
}
