-- The active colorscheme is `ethereal` (see init.lua), a standalone file at
-- colors/ethereal.lua baked from ~/.config/themes/ethereal/colors.toml.
-- To regenerate it, see the note at the top of that file.
return {
    {
        "navarasu/onedark.nvim",
        config = function()
            require('onedark').setup {
                style = 'light'
            }
            require('onedark').load()
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
        -- priority = 1000,
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
            -- vim.cmd("colorscheme github_light_high_contrast")
        end,
    },
}
