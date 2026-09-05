---@alias NixOSConfigName string

---@class NixHelper
---@field get_nixos_expr fun(): string
---@field get_nixos_config fun(): NixOSConfigName|nil

---@return string|nil
local function get_flake_root()
  local cwd = vim.fn.getcwd()
  local root = vim.fn.findfile("flake.nix", cwd .. ";")

  if root == "" then
    return nil
  end

  return vim.fn.fnamemodify(root, ":h")
end

---@return NixOSConfigName|nil
local function get_nixos_config()
  local flake_dir = get_flake_root()

  if not flake_dir then
    return nil
  end

  local result = vim
    .system({
      "nix",
      "eval",
      "--json",
      flake_dir .. "#nixosConfigurations",
      "--apply",
      "builtins.attrNames",
    }, { text = true })
    -- Bounded because this runs on the UI thread from lspconfig's config(),
    -- which LazyVim loads on the first file opened -- so an eval that hangs
    -- freezes nvim at exactly that moment. A warm eval is ~60ms; a cold one
    -- that outruns this loses nixd's NixOS option completions until restart,
    -- which is the cheaper failure.
    :wait(3000)

  if result.code ~= 0 then
    return nil
  end

  local configs = vim.json.decode(result.stdout)
  local hostname = vim.fn.hostname()

  for _, name in ipairs(configs) do
    if name == hostname then
      return name
    end
  end

  if #configs == 1 then
    return configs[1]
  end

  return nil
end

---@return string
local function get_nixos_expr()
  local config = get_nixos_config()

  if not config then
    return ""
  end

  return string.format("(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.%s.options", config)
end

---@type NixHelper
return {
  get_nixos_expr = get_nixos_expr,
  get_nixos_config = get_nixos_config,
}
