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
vim.keymap.set("n", "<leader>w", ":w<CR>")

-- Fast source reload
vim.keymap.set("n", "<leader>\\", ":so<CR>")

-- Center cursor vertically when navigating
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Center cursor vertically when navigating
vim.keymap.set("n", "H", "^")
vim.keymap.set("n", "L", "$")
