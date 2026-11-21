-- Lualine theme for the herdr-vivid colorscheme. lualine's "auto" theme loads it
-- by colors_name and rebuilds it on every ColorScheme event, so it follows
-- 'background' the same way the colorscheme does.

local p = require("herdr-vivid").palette()

local function mode(color)
    return {
        a = { fg = p.bg, bg = color, gui = "bold" },
        b = { fg = p.fg, bg = p.statusline },
        c = { fg = p.muted, bg = p.statusline },
    }
end

local inactive = { fg = p.dim, bg = p.chrome }

return {
    normal = mode(p.accent),
    insert = mode(p.green),
    visual = mode(p.purple),
    replace = mode(p.red),
    command = mode(p.yellow),
    terminal = mode(p.cyan),
    inactive = { a = inactive, b = inactive, c = inactive },
}
