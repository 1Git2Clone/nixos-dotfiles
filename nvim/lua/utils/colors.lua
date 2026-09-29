-- Every colour the config picks, read from caelestia's live scheme and
-- re-read whenever it switches (M.watch). The literals are the fallback for a
-- machine with no caelestia.
local M = {}

local scheme_dir = (vim.env.XDG_STATE_HOME or vim.fn.expand '~/.local/state') .. '/caelestia'

---@type table<string, string>
local fallback = {
  base = '#110000',
  primary = '#ff5077',
  secondary = '#ff9999',
  onSecondaryContainer = '#ffaa88',
  red = '#ff003e',
  term5 = '#da5876',
  primaryFixedDim = '#ffb3c3',
}

-- The nine-step pink catppuccin's greys are overridden with.
local ramp_names = { 'text', 'subtext1', 'subtext0', 'overlay2', 'overlay1', 'overlay0', 'surface2', 'surface1', 'surface0' }
local ramp_fallback = { '#f7c0c8', '#e6aab3', '#d4939d', '#c17c87', '#ab6670', '#965159', '#7f3e44', '#6a2f36', '#541f27' }

---@return table<string, string>?
local function read_scheme()
  local f = io.open(scheme_dir .. '/scheme.json', 'r')
  if not f then return nil end
  local ok, scheme = pcall(vim.json.decode, f:read '*a')
  f:close()
  if not ok or type(scheme) ~= 'table' or type(scheme.colours) ~= 'table' then return nil end
  return vim.tbl_map(function(c) return '#' .. c end, scheme.colours)
end

-- Straight sRGB interpolation, n steps from a to b inclusive.
local function ramp(a, b, n)
  local function rgb(hex) return { tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16) } end
  local x, y, out = rgb(a), rgb(b), {}
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local c = {}
    for j = 1, 3 do
      c[j] = math.floor(x[j] + (y[j] - x[j]) * t + 0.5)
    end
    out[#out + 1] = string.format('#%02x%02x%02x', c[1], c[2], c[3])
  end
  return out
end

function M.reload()
  local s = read_scheme()
  local c = s or fallback

  -- The whole scheme, for what wants more than the picks below; nil without
  -- caelestia.
  ---@type table<string, string>?
  M.scheme = s

  ---@type { base: string, mantle: string, crust: string }
  M.catppuccin = { base = c.base, mantle = c.base, crust = c.base }
  ---@type string
  M.default_fg = c.primary
  ---@type string
  M.default_bg = c.base
  ---@type string
  M.module_col = c.secondary
  ---@type string
  M.enum_member_col = c.onSecondaryContainer
  ---@type { fg: string, bg: string }
  M.default_fg_bg = { fg = M.default_fg, bg = M.default_bg }
  ---@type string
  M.line_hl_col = c.red
  ---@type string
  M.hl_col = c.onSecondaryContainer
  ---@type string
  M.line_col = c.term5
  ---@type string
  M.comment_col = c.primaryFixedDim

  local steps = ramp_fallback
  if s then
    steps = ramp(s.flamingo, s.mauve, 5)
    vim.list_extend(steps, ramp(s.mauve, s.onSecondaryFixedVariant, 5), 2)
  end
  ---@type table<string, string>
  M.ramp = {}
  for i, name in ipairs(ramp_names) do
    M.ramp[name] = steps[i]
  end
end

-- Calls `on_change` after caelestia writes a new scheme.json. The directory is
-- watched, not the file: caelestia replaces it, which a file watch loses.
---@param on_change fun()
function M.watch(on_change)
  local handle = vim.uv.new_fs_event()
  local timer = vim.uv.new_timer()
  if not handle or not timer then return end
  handle:start(scheme_dir, {}, function(_, filename)
    if filename ~= 'scheme.json' then return end
    -- One switch is several writes; settle before re-applying.
    timer:start(100, 0, vim.schedule_wrap(on_change))
  end)
end

M.reload()

return require('utils.generic').make_constant(M)
