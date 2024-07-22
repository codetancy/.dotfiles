return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")

		conform.setup({
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_format" },
			},
			format_on_save = {
				lsp_fallback = true,
				async = false,
				timeout_ms = 1000,
			},
		})

		local format_fn = function()
			conform.format({ lsp_fallback = true, async = false, timeout_ms = 1000 })
		end
		vim.keymap.set({ "n", "v" }, "<leader>f", format_fn, { desc = "Format file or range", silent = true })
	end,
}
