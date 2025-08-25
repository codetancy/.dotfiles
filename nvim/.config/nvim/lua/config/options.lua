-- :help options

vim.opt.hlsearch = false      -- No highlighting for word searching

vim.opt.number = true         -- Show current line number
vim.opt.relativenumber = true -- Relative line number for better commands

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.updatetime = 250

vim.opt.mouse = "a" -- Supports mouse in all modes

vim.opt.tabstop = 4 -- Four spaces for tabs
vim.opt.shiftwidth = 4
vim.opt.expandtab = true -- Converts tabs to spaces

vim.opt.showmode = false -- With lualine we dont need for mode to show

vim.opt.wrap = false     -- I dont want lines to wrap
vim.opt.whichwrap = ""   -- Keys that allow for sideway navigation

vim.opt.scrolloff = 8

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.laststatus = 3

vim.opt.colorcolumn:append("80")
