-- vim.api.nvim_create_autocmd('QuickFixCmdPost', {
--     group = vim.api.nvim_create_augroup('my.lcl', {}),
--     callback = function()
--         vim.cmd.lclose()
--     end
-- })

vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost" }, {
	pattern = { "*.fs", "*.fsx", "*.fsi" },
	callback = function()
		vim.api.nvim_buf_set_option(0, "cms", "// %s")
	end,
})

-- vim.api.nvim_create_autocmd({ "FileType" }, {
-- 	pattern = { "markdown" },
--     command = 'setlocal conceallevel=1'
-- })
