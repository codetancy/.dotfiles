local state = {
    terminal = {
        buf = -1,
        win = -1
    },
    loclist = {
        buf = -1,
        win = -1
    }
}

local function create_window(opts)
    local buf = nil
    if vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win = vim.api.nvim_open_win(buf, true, {
        split = 'below',
    })
    return { buf = buf, win = win }
end

local function win_is_open(w)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if w == win then
            return true
        end
    end

    return false
end


vim.api.nvim_create_user_command('ToggleTerminal', function()
    if not vim.api.nvim_win_is_valid(state.terminal.win) then
        state.terminal = create_window({ buf = state.terminal.buf })
        if vim.bo[state.terminal.buf].buftype ~= 'terminal' then
            vim.cmd.term()
        end
    else
        vim.api.nvim_win_hide(state.terminal.win)
    end
end, {})

vim.keymap.set("n", "<leader>t", ":ToggleTerminal<CR>")
