return {
	"neovim/nvim-lspconfig",
	cmd = { "LspInfo", "LspInstall", "LspStart" },
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		"williamboman/mason-lspconfig.nvim",
	},
	config = function()
		-- Diagnostic symbols
		local signs = {
			{ name = "DiagnosticSignError", text = "E" },
			{ name = "DiagnosticSignWarn", text = "W" },
			{ name = "DiagnosticSignHint", text = "H" },
			{ name = "DiagnosticSignInfo", text = "I" },
		}

		for _, sign in pairs(signs) do
			vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
		end

		local lsp_zero = require("lsp-zero")
		lsp_zero.extend_lspconfig()

		lsp_zero.on_attach(function(_, bufnr)
			local opts = { buffer = bufnr, noremap = true, silent = true }

			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)

			--View references
			vim.keymap.set("n", "<leader>vr", ":Telescope lsp_references<CR>", opts)

			-- Show documentation for what is under cursor
			vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
			vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)

			-- See available quick fixes
			vim.keymap.set("n", "<space>qf", vim.lsp.buf.code_action, opts)

			-- Rename symbol under the caret
			vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)

			-- Diagnostics navigation
			vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
			vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

			-- View diagnostic
			vim.keymap.set("n", "<space>vd", vim.diagnostic.open_float, opts)

			-- View buffer diagnostics
			vim.keymap.set("n", "<space>vD", ":Telescope diagnostics bufnr=0<CR>", opts)
		end)

		local capabilities = require("cmp_nvim_lsp").default_capabilities()
		local lspconfig = require("lspconfig")
		local mason_lspconfig = require("mason-lspconfig")
		mason_lspconfig.setup_handlers({
			function(server_name)
				lspconfig[server_name].setup({
					capabilities = capabilities,
				})
			end,
			["lua_ls"] = function()
				-- configure lua server (with special settings)
				lspconfig["lua_ls"].setup({
					settings = {
						Lua = {
							-- make the language server recognize "vim" global
							diagnostics = {
								globals = { "vim" },
							},
							capabilities = capabilities,
						},
					},
				})
			end,
		})
	end,
}
