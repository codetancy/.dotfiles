return {
    {
        "ellisonleao/gruvbox.nvim",
        -- priority = 1000,
        config = function()
            require("gruvbox").setup({
                italic = {
                    strings = false,
                },
            })
            -- vim.cmd("colorscheme gruvbox")
        end,
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            vim.cmd("colorscheme catppuccin-mocha")
        end,
    }
}
