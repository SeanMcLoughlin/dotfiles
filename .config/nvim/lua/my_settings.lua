local set = vim.opt
local global = vim.g

-- Functional wrapper for mapping custom keybindings
function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

global.mapleader = ","

set.number = true
set.tabstop = 4
set.softtabstop = 4
set.shiftwidth = 4
set.expandtab = true

map('n', '<leader>b', ':NvimTreeToggle<CR>')
