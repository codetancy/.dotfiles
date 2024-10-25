return {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "catppuccin/nvim",
    },
    config = function()
        require("lualine").setup({
            options = {
                theme = "catppuccin",
            },
            sections = {
                lualine_a = {
                    "mode",
                },
                lualine_b = {},
                lualine_c = {
                    {
                        "filename",
                        path = 0,
                    },
                },
                lualine_x = {
                    "filetype",
                },
                lualine_y = {
                    {
                        "diagnostics",
                        symbols = {
                            error = "E",
                            warn = "W",
                            info = "I",
                            hint = "H",
                        },
                    },
                },
                lualine_z = { "location" },
            },
        })
    end,
}
