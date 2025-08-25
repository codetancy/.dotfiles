-- When using osc52, depending of your terminal emulator you may have to
-- explicitly enable the escape sequence for pasting

-- In Alacritty the default is CopyOnly. Change to:
-- [terminal]
-- osc52 = "CopyPaste"

vim.g.clipboard = 'osc52'
