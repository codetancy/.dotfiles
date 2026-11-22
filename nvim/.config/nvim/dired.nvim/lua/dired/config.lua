local M = {}

M.defaults = {
    hijack_netrw = true,
    show_hidden = true,
    dirs_first = true,
    details = true,
    sort = "name",
    dwim_target = true,
    keymaps = {},
}

M.options = vim.deepcopy(M.defaults)

function M.set(opts)
    M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
