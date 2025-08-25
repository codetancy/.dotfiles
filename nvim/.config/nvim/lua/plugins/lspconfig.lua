return {
    "neovim/nvim-lspconfig",
    dependencies = {},
    config = function()
        -- To see a list of all the language servers and how to install them,
        -- use :help lspconfig-all
        -- Use :checkhealth to check for any errors with vim.lsp
        -- Make sure the installed LSP server are findable in $PATH
        -- Use :echo executable(...) to check if neovim finds the executable
        local lsps = {
            lua_ls = {
                settings = {
                    Lua = {
                        -- make the language server recognize "vim" global
                        diagnostics = {
                            globals = { "vim" },
                        },
                    }
                }
            },
            clangd = {},
            gopls = {}
        }

        for server, config in pairs(lsps) do
            vim.lsp.config(server, config)
            vim.lsp.enable(server)
        end

        vim.api.nvim_create_user_command('ToggleLoclist', function()
            local conf = vim.fn.getloclist(0, { winid = 1 })
            if conf.winid == 0 then
                vim.diagnostic.setloclist()
            else
                vim.cmd.lclose()
            end
        end, {})

        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('my.lsp', {}),
            callback = function()
                -- For a full list of capabilities, run:
                -- :lua =vim.lsp.get_clients()[1].server_capabilities
                -- Then check client.server_capabilities.xxxProvider from
                -- local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
                vim.keymap.set("n", "<leader>l", ":ToggleLoclist<CR>")
                vim.keymap.set("n", "<leader>rn", function() vim.lsp.buf.rename() end)
                vim.keymap.set("n", "<leader>m", function() vim.diagnostic.open_float() end)
            end
        })

        vim.diagnostic.config({
            virtual_lines = true
        })

    end
}
