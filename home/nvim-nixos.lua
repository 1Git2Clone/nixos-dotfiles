-- Dropped into lua/plugins/ of the nvim-config flake input by home/hutao.nix.
-- Only NixOS gets it, so nvim-config itself stays portable.
--
-- LazyVim's lang extras resolve tool paths under mason's root and warn once
-- per package that is not installed. mason is disabled here on purpose (its
-- prebuilt binaries cannot exec without an FHS layout — see utils/nix.lua), so
-- every one of those extras warns on every start.
--
-- The paths stay wrong-but-harmless: the extras that use them (svelte, astro)
-- hand them to vtsls, which ignores a plugin directory that does not exist.

---@module "lazy"
---@type LazySpec[]
return {
  {
    "LazyVim/LazyVim",
    optional = true,
    init = function()
      local Util = require("lazyvim.util")
      local get_pkg_path = Util.get_pkg_path

      Util.get_pkg_path = function(pkg, path, opts)
        return get_pkg_path(pkg, path, vim.tbl_extend("force", opts or {}, { warn = false }))
      end
    end,
  },
}
