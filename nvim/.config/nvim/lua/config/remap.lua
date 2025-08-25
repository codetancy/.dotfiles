-- Use vim.inspect(...) to see the contents of a table

-- The buffer documentation is :help api-buffer
-- The window documentation is :help api-window

-- Use vim.cmd.startinsert() to enter insert mode

-- Defaults:
-- [b ]b navigate between buffers
-- [q ]q navigate between quickfix
-- [l ]l navigate between loclist

-- Map leader to space
vim.g.mapleader = " "

vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- Escape
vim.keymap.set({ "i", "v", "x" }, "<C-j>", "<Esc>")

-- Disable keys
vim.keymap.set("n", "<BS>", "<Nop>")
vim.keymap.set("n", "Q", "<Nop>")

-- [O]pen [E]xplorer
vim.keymap.set("n", "<C-e>", ":Ex<CR>")

-- Fast [W]rite
vim.keymap.set("n", "<leader>w", ":w<CR>", { silent = true })

-- Center cursor vertically when navigating
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Center cursor vertically when navigating
vim.keymap.set("n", "H", "^")
vim.keymap.set("n", "L", "$")

-- Yank to clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", "\"+y")

-- Discard delete
vim.keymap.set("n", "x", "\"_x")
vim.keymap.set("n", "r", "\"_r")

-- Paste from clipboard
vim.keymap.set("n", "<leader>p", "\"+p")
vim.keymap.set("v", "<leader>p", "\"+P")

-- Terminal mode navigation
vim.keymap.set("t", "<C-j>", "<C-\\><C-N>")
vim.keymap.set("t", "<Esc>", "<C-\\><C-N>")

vim.keymap.set("t", "<C-w>h", "<C-\\><C-N><C-w>h")
vim.keymap.set("t", "<C-w>j", "<C-\\><C-N><C-w>j")
vim.keymap.set("t", "<C-w>k", "<C-\\><C-N><C-w>k")
vim.keymap.set("t", "<C-w>l", "<C-\\><C-N><C-w>l")

vim.keymap.set("n", "gn", ":bn<CR>")
vim.keymap.set("n", "gp", ":bp<CR>")
