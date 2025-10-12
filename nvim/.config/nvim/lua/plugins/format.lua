return {
	"stevearc/conform.nvim",
	config = function()
		require("conform").setup({
			formatters_by_ft = {
				lua = { "stylua" },
				fsharp = { "fantomas" },
			},
		})

		vim.keymap.set("n", "<leader>f", function()
			require("conform").format({ async = true })
            vim.notify("formatted", vim.log.levels.INFO)
		end)
	end,
}
