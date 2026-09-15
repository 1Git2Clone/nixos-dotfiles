---@module "lazy"
---@type LazySpec
return {
  {
    "stevearc/quicker.nvim",
    ft = "qf",
    -- `edit.enabled` is on by default: the list is a normal buffer, so `dd`
    -- plus `:w` drops entries and editing the text rewrites the real files.
    -- LazyVim already binds <leader>xq to open it.
    opts = {},
  },
}
