---@module "lazy"
---@type LazySpec
return {
  {
    "folke/noice.nvim",
    -- noice replaces vim.lsp.buf.hover with a per-client buf_request whose
    -- handler notifies on every empty reply. Neovim's own aggregates instead
    -- and speaks up only if *all* clients came back empty, so a buffer with
    -- eslint or tailwindcss attached beside ts_ls gets the real hover window
    -- plus one "No information available" per server that has no hover.
    -- ponytail: silences the genuine no-docs case too; the window simply not
    -- opening is the same signal. Drop this if noice ever filters by
    -- hoverProvider.
    opts = { lsp = { hover = { silent = true } } },
  },
}
