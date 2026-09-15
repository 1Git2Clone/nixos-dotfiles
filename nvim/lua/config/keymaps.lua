vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>')

-- Change focused windows easier
vim.keymap.set('n', '<C-h>', '<C-w><C-h>')
vim.keymap.set('n', '<C-l>', '<C-w><C-l>')
vim.keymap.set('n', '<C-j>', '<C-w><C-j>')
vim.keymap.set('n', '<C-k>', '<C-w><C-k>')

vim.keymap.set('n', '<leader>fe', '<cmd>Neotree toggle<CR>', { desc = 'Toggle Explorer' })
vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', '<cmd>w<CR>', { desc = 'Save file' })

-- change indentation and keep selection
vim.keymap.set('v', '<', '<gv', opts)
vim.keymap.set('v', '>', '>gv', opts)

-- Delete quickfix entries relative to the current one
local function qf_remove(offset)
  local qf = vim.fn.getqflist()
  local idx = vim.fn.getqflist({ idx = 0 }).idx

  for _ = 1, vim.v.count1 do
    local target = idx + offset
    if target < 1 or target > #qf then
      break
    end

    table.remove(qf, target)

    -- deleting before the current entry shifts it down
    if target < idx then
      idx = idx - 1
    end
  end

  vim.fn.setqflist(qf, 'r')

  if #qf > 0 then
    vim.fn.setqflist({}, 'a', { idx = math.min(idx, #qf) })
  end
end

vim.keymap.set('n', '<leader>qx', function()
  qf_remove(0)
end, { desc = 'Delete current quickfix entry' })

vim.keymap.set('n', '<leader>qn', function()
  qf_remove(1)
end, { desc = 'Delete next quickfix entry' })

vim.keymap.set('n', '<leader>qp', function()
  qf_remove(-1)
end, { desc = 'Delete previous quickfix entry' })
