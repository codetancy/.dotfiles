local primary = 'gruvbox-baby'
local fallback = 'gruvbox'

local ok_status  = pcall(vim.cmd, 'colorscheme ' .. primary)
if ok_status then
  return
end

ok_status, _ = pcall(vim.cmd, 'colorscheme ' .. fallback)
if not ok_status then
  return
end
