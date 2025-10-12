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
            gopls = {
                settings = {
                    gopls = {
                        linkTarget = "pkg.go.dev",
                    }
                }
            },
            -- fsautocomplete = {
            --     settings = {
            --         FSharp = {
            --         }
            --     }
            -- }
        }

        for server, config in pairs(lsps) do
            vim.lsp.config(server, config)
            vim.lsp.enable(server)
        end

        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('my.lsp', {}),
            callback = function(args)
                local opts = { buffer = args.buf }
                -- For a full list of capabilities, run:
                -- :lua =vim.lsp.get_clients()[1].server_capabilities
                -- Then check client.server_capabilities.xxxProvider from
                -- local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
                vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
                vim.keymap.set("n", "<leader>qf", function() vim.lsp.buf.code_action() end, opts)
                vim.keymap.set("n", "<leader>rn", function() vim.lsp.buf.rename() end, opts)
                vim.keymap.set("n", "<leader>m", function() vim.diagnostic.open_float() end, opts)

                -- Somewhat I have to manually unset the default in order to
                -- override it
                vim.keymap.del("n", "K", opts)
                vim.keymap.set("n", "K", function()
                    vim.lsp.buf.hover({
                        max_width = 80,
                        max_height = 15,
                        wrap = false,
                        border = 'rounded'
                    })
                end, opts)
            end
        })

    end
}
