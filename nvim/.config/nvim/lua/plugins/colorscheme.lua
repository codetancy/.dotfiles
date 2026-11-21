-- The active colorscheme is `herdr-vivid` (colors/herdr-vivid.lua), set in init.lua.
-- The plugins below are installed alternatives.
return {
    {
        "navarasu/onedark.nvim",
        config = function()
            require('onedark').setup {
                style = 'light'
            }
        end
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        -- priority = 1000,
        config = function()
            -- vim.cmd("colorscheme catppuccin-mocha")
        end,
    },
    {
        "projekt0n/github-nvim-theme",
        name = "github-theme",
        lazy = false,
        priority = 1000,
        config = function()
            require('github-theme').setup({
                options = {
                    styles = {
                        comments = 'italic',
                        keywords = 'bold',
                        types = 'italic,bold'
                    }
                }
            })
        end,
    },
}
