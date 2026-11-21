-- Herdr Vivid: bright ANSI syntax colors on the Herdr canvas, bold keywords,
-- italic types and parameters.
--
-- 'background' picks the theme: dark is Herdr graphite, light is Herdr paper.
-- Colors are Herdr's own theme tokens (themes() in herdr-app); the editor sits
-- on the canvas token, one step darker than the pane, so it reads as inset.

local M = {}

M.themes = {
    graphite = {
        bg = "#131518",
        chrome = "#101114",
        raised = "#2c2e31",
        popover = "#25272b",
        fg = "#eeeeef",
        muted = "#98999b",
        dim = "#696a6d",
        selection = "#394454",
        accent = "#96b2d7",
        border = "#2e3034",
        working = "#e5c07b",
        ansi = {
            "#45484f", "#dc8c95", "#a6bd91", "#d8be87", "#96b2d7", "#b5a2ce", "#8cbdc3", "#d2d4d9",
            "#818793", "#f0a5ad", "#bad5a2", "#ead2a1", "#b0cbef", "#cbb7e6", "#a4d5db", "#f0f0f2",
        },
        statusline = "#2c2e31",
        statusline_nc = "#101114",
        cursor_line = 0.045,
        color_column = 0.025,
        tint = 0.16,
        virtual_text = 0.10,
        diff_text = 0.30,
        param_toward_fg = 0.45,
    },
    paper = {
        bg = "#fafaf9",
        chrome = "#f1f1ee",
        raised = "#f6f6f6",
        popover = "#ffffff",
        fg = "#1b1b1e",
        muted = "#69696b",
        dim = "#969698",
        selection = "#cfdcf5",
        accent = "#1f62d0",
        border = "#e8e8e8",
        working = "#9a6700",
        ansi = {
            "#25272c", "#c62a2a", "#1a7f37", "#8f5d00", "#1f62d0", "#7a45c8", "#0f6f74", "#5f6068",
            "#7b7e87", "#d1242f", "#1f883d", "#9a6700", "#0969da", "#8250df", "#1b7c83", "#111214",
        },
        statusline = "#f1f1ee",
        statusline_nc = "#fafaf9",
        cursor_line = 0.035,
        color_column = 0.02,
        tint = 0.12,
        virtual_text = 0.07,
        diff_text = 0.22,
        param_toward_fg = 0,
    },
}

local function blend(from, to, t)
    local out = "#"
    for i = 2, 6, 2 do
        local a = tonumber(from:sub(i, i + 1), 16)
        local b = tonumber(to:sub(i, i + 1), 16)
        out = out .. string.format("%02x", math.floor(a + (b - a) * t + 0.5))
    end
    return out
end

function M.palette()
    local t = vim.o.background == "light" and M.themes.paper or M.themes.graphite
    local a = t.ansi
    return setmetatable({
        red = a[2], green = a[3], yellow = a[4], blue = a[5], purple = a[6], cyan = a[7],
        comment = a[9], constant = a[10], string = a[11], type = a[12], func = a[13],
        keyword = a[14], operator = a[15],
        param = blend(a[12], t.fg, t.param_toward_fg),
    }, { __index = t })
end

function M.highlights(p)
    local tint = function(c, amount) return blend(p.bg, c, amount or p.tint) end
    local cursor_line = blend(p.bg, p.fg, p.cursor_line)
    local kw = { fg = p.keyword, bold = true }
    local ty = { fg = p.type, italic = true }
    local g = {
        Normal = { fg = p.fg, bg = p.bg },
        NormalNC = { fg = p.fg, bg = p.bg },
        NormalFloat = { fg = p.fg, bg = p.popover },
        FloatBorder = { fg = p.border, bg = p.popover },
        FloatTitle = { fg = p.fg, bg = p.popover, bold = true },
        Cursor = { fg = p.bg, bg = p.fg },
        lCursor = { link = "Cursor" },
        TermCursor = { link = "Cursor" },
        CursorLine = { bg = cursor_line },
        CursorColumn = { bg = cursor_line },
        ColorColumn = { bg = blend(p.bg, p.fg, p.color_column) },
        LineNr = { fg = p.dim },
        CursorLineNr = { fg = p.fg, bold = true },
        SignColumn = { fg = p.dim, bg = p.bg },
        FoldColumn = { fg = p.dim, bg = p.bg },
        Folded = { fg = p.muted, bg = cursor_line },
        WinSeparator = { fg = p.border },
        VertSplit = { link = "WinSeparator" },
        StatusLine = { fg = p.fg, bg = p.statusline },
        StatusLineNC = { fg = p.dim, bg = p.statusline_nc },
        TabLine = { fg = p.muted, bg = p.chrome },
        TabLineFill = { bg = p.chrome },
        TabLineSel = { fg = p.fg, bg = p.bg, bold = true },
        WinBar = { fg = p.muted, bg = p.bg },
        WinBarNC = { fg = p.dim, bg = p.bg },
        Pmenu = { fg = p.fg, bg = p.popover },
        PmenuSel = { fg = p.fg, bg = p.selection },
        PmenuSbar = { bg = p.popover },
        PmenuThumb = { bg = p.border },
        PmenuMatch = { fg = p.accent, bold = true },
        Visual = { bg = p.selection },
        VisualNOS = { link = "Visual" },
        Search = { fg = p.bg, bg = p.working },
        CurSearch = { fg = p.bg, bg = vim.o.background == "light" and p.type or p.yellow, bold = true },
        IncSearch = { link = "CurSearch" },
        Substitute = { link = "Search" },
        MatchParen = { bg = p.selection, bold = true },
        NonText = { fg = blend(p.bg, p.dim, 0.7) },
        Whitespace = { link = "NonText" },
        EndOfBuffer = { link = "NonText" },
        SpecialKey = { link = "NonText" },
        Directory = { fg = p.accent },
        Title = { fg = p.fg, bold = true },
        Question = { fg = p.green },
        MoreMsg = { fg = p.green },
        ModeMsg = { fg = p.muted },
        ErrorMsg = { fg = p.red },
        WarningMsg = { fg = p.yellow },
        Conceal = { fg = p.dim },
        QuickFixLine = { bg = p.selection },
        SpellBad = { undercurl = true, sp = p.red },
        SpellCap = { undercurl = true, sp = p.yellow },
        SpellRare = { undercurl = true, sp = p.purple },
        SpellLocal = { undercurl = true, sp = p.cyan },
        DiffAdd = { bg = tint(p.green) },
        DiffChange = { bg = tint(p.blue) },
        DiffDelete = { fg = p.red, bg = tint(p.red) },
        DiffText = { bg = tint(p.blue, p.diff_text) },
        Added = { fg = p.green },
        Changed = { fg = p.blue },
        Removed = { fg = p.red },
        DiagnosticUnnecessary = { fg = p.dim },
        LspReferenceText = { bg = cursor_line },
        LspReferenceRead = { link = "LspReferenceText" },
        LspReferenceWrite = { link = "LspReferenceText" },
        LspInlayHint = { fg = p.dim, italic = true },

        Comment = { fg = p.comment, italic = true },
        Constant = { fg = p.constant },
        String = { fg = p.string },
        Character = { fg = p.string },
        Number = { fg = p.constant },
        Boolean = { fg = p.constant },
        Float = { fg = p.constant },
        Identifier = { fg = p.fg },
        Function = { fg = p.func },
        Statement = kw,
        Conditional = kw,
        Repeat = kw,
        Label = kw,
        Keyword = kw,
        Exception = kw,
        Operator = { fg = p.operator },
        PreProc = { fg = p.keyword },
        Include = { fg = p.keyword },
        Define = { fg = p.keyword },
        Macro = { fg = p.keyword },
        PreCondit = { fg = p.keyword },
        Type = ty,
        StorageClass = kw,
        Structure = kw,
        Typedef = kw,
        Special = { fg = p.working },
        SpecialChar = { fg = p.working },
        Tag = { fg = p.working },
        Debug = { fg = p.working },
        Delimiter = { fg = p.muted },
        SpecialComment = { fg = p.comment, italic = true, bold = true },
        Underlined = { underline = true },
        Error = { fg = p.red },
        Todo = { fg = p.bg, bg = p.working, bold = true },

        ["@variable"] = { fg = p.fg },
        ["@variable.builtin"] = { link = "Special" },
        ["@variable.parameter"] = { fg = p.param, italic = true },
        ["@variable.member"] = { fg = p.fg },
        ["@property"] = { fg = p.fg },
        ["@constant"] = { link = "Constant" },
        ["@constant.builtin"] = { link = "Constant" },
        ["@module"] = { link = "Type" },
        ["@string"] = { link = "String" },
        ["@string.escape"] = { link = "SpecialChar" },
        ["@string.special"] = { link = "SpecialChar" },
        ["@character"] = { link = "Character" },
        ["@number"] = { link = "Number" },
        ["@boolean"] = { link = "Boolean" },
        ["@type"] = { link = "Type" },
        ["@type.builtin"] = { link = "Type" },
        ["@attribute"] = { link = "PreProc" },
        ["@function"] = { link = "Function" },
        ["@function.builtin"] = { link = "Special" },
        ["@function.call"] = { fg = p.func },
        ["@function.method.call"] = { fg = p.func },
        ["@constructor"] = { link = "Type" },
        ["@constructor.lua"] = { link = "Delimiter" },
        ["@operator"] = { link = "Operator" },
        ["@keyword"] = { link = "Keyword" },
        ["@keyword.function"] = { link = "Keyword" },
        ["@keyword.return"] = { link = "Keyword" },
        ["@keyword.import"] = { link = "Include" },
        ["@punctuation"] = { link = "Delimiter" },
        ["@punctuation.bracket"] = { link = "Delimiter" },
        ["@punctuation.delimiter"] = { link = "Delimiter" },
        ["@comment"] = { link = "Comment" },
        ["@tag"] = { link = "Tag" },
        ["@markup.heading"] = { link = "Title" },
        ["@markup.link"] = { link = "Directory" },
        ["@markup.raw"] = { link = "String" },
        ["@markup.strong"] = { bold = true },
        ["@markup.italic"] = { italic = true },
        ["@lsp.type.function"] = { link = "Function" },
        ["@lsp.type.method"] = { link = "Function" },
        ["@lsp.type.class"] = { link = "Type" },
        pythonFunction = { fg = p.func },

        TelescopeNormal = { link = "NormalFloat" },
        TelescopeBorder = { link = "FloatBorder" },
        TelescopeSelection = { bg = p.selection },
        TelescopeMatching = { fg = p.accent, bold = true },
        GitSignsAdd = { fg = p.green },
        GitSignsChange = { fg = p.blue },
        GitSignsDelete = { fg = p.red },
    }
    for level, color in pairs({ Error = p.red, Warn = p.yellow, Info = p.blue, Hint = p.cyan, Ok = p.green }) do
        g["Diagnostic" .. level] = { fg = color }
        g["DiagnosticUnderline" .. level] = { undercurl = true, sp = color }
        g["DiagnosticVirtualText" .. level] = { fg = color, bg = tint(color, p.virtual_text) }
        g["DiagnosticSign" .. level] = { link = "Diagnostic" .. level }
    end
    return g
end

function M.load()
    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then
        vim.cmd("syntax reset")
    end
    vim.g.colors_name = "herdr-vivid"
    vim.o.termguicolors = true
    local p = M.palette()
    for i, color in ipairs(p.ansi) do
        vim.g["terminal_color_" .. (i - 1)] = color
    end
    for group, spec in pairs(M.highlights(p)) do
        vim.api.nvim_set_hl(0, group, spec)
    end
end

return M
