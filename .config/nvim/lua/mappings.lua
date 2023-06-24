-- Disable space key prior to mapping
vim.keymap.set("", "<Space>", "<Nop>", { noremap = true, silent = true })

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set({ "i", "v" }, "<C-j>", "<Esc>",
  { noremap = true, silent = true, desc = 'Exit mode' })

-- Faster save
vim.keymap.set("n", "<leader>w", ":w<CR>",
  { noremap = true, silent = true, desc = 'Write file' })

-- Editor navigation
vim.keymap.set("", "H", "^")
vim.keymap.set("", "L", "$")

vim.keymap.set("n", "<C-u>", "<C-u>zz",
  { noremap = true, silent = true, desc = 'Scroll up' })
vim.keymap.set("n", "<C-d>", "<C-d>zz",
  { noremap = true, silent = true, desc = 'Scroll down' })

vim.keymap.set("n", "n", "nzz",
  { noremap = true, silent = true, desc = 'Next match' })
vim.keymap.set("n", "N", "Nzz",
  { noremap = true, silent = true, desc = 'Previous match' })

-- Buffer navigation
vim.keymap.set('n', '<leader>bc', function() pcall(vim.cmd, 'bd') end,
  { noremap = true, silent = true, desc = 'Close buffer' })
vim.keymap.set('n', '<leader>bp', function() pcall(vim.cmd, 'bp') end,
  { noremap = true, silent = true, desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bn', function() pcall(vim.cmd, 'bn') end,
  { noremap = true, silent = true, desc = 'Previous buffer' })

-- Operations over system clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", "\"+y",
  { noremap = true, silent = true, desc = 'Copy to clipboard' })
vim.keymap.set({ "n", "v" }, "<leader>p", "\"+p",
  { noremap = true, silent = true, desc = 'Paste from clipboard below' })
vim.keymap.set({ "n", "v" }, "<leader>P", "\"+P",
  { noremap = true, silent = true, desc = 'Paste from clipboard above' })
vim.keymap.set({ "n", "v" }, "<leader>d", "\"+d",
  { noremap = true, silent = true, desc = 'Cut to clipboard' })

-- Delete into empty register
vim.keymap.set({ "n", "v" }, "x", "\"_x",
  { noremap = true, silent = true, desc = 'Delete character' })
vim.keymap.set({ "n", "v" }, "r", "\"_r",
  { noremap = true, silent = true, desc = 'Replace character' })

-- Open explorer
vim.keymap.set("n", "<C-e>", ":Ex<Cr>", { desc = 'Open explorer' })
