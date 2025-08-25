local mode_map = {
  ['NORMAL'] = 'N',
  ['INSERT'] = 'I',
  ['VISUAL'] = 'V',
  ['REPLACE'] = 'R',
  ['COMMAND'] = 'C',
  ['TERMINAL'] = 'T',
  ['SELECT'] = 'S',
  ['SHELL'] = 'SH',
  ['EX'] = 'X',
  ['V-BLOCK'] = 'VB',
  ['V-LINE'] = 'VL',
  ['V-REPLACE'] = 'VR',
  ['S-BLOCK'] = 'SB',
  ['S-LINE'] = 'SL',
  ['CONFIRM'] = 'Y?',
  ['O-PENDING'] = 'N?',
  ['MORE'] = 'M',
}

local flavour = "mocha"

return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            require('catppuccin').setup({
                transparent_background = true,
                styles = {
                    keywords = { "bold" },
                    functions = { "italic" },
                },
            })
            vim.cmd.colorscheme("catppuccin-"..flavour)
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        lazy = false,
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "catppuccin/nvim",
        },
        config = function()
            local palette = require("catppuccin.palettes").get_palette(flavour)
            local get_lualine_theme = require("catppuccin.utils.lualine")
            local custom = get_lualine_theme(flavour)

            custom.normal.c.bg = palette.mantle
            custom.inactive.a.bg = palette.mantle
            custom.inactive.b.bg = palette.mantle
            custom.inactive.c.bg = palette.mantle

            require("lualine").setup({
                options = {
                    theme = custom,
                },
                sections = {
                    lualine_a = {
                        {
                            "mode",
                            fmt = function(str)
                                return mode_map[str] or str
                            end
                        }
                    },
                    lualine_b = {},
                    lualine_c = {
                        {
                            "filename",
                            path = 0,
                        },
                    },
                    lualine_x = {
                        "lsp_status",
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
    },
}

