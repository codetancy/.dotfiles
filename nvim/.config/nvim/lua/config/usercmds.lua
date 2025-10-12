vim.api.nvim_create_user_command('ToggleLoclist', function()
    -- local conf = vim.fn.getloclist(0, { winid = 1 })
    -- if conf.winid == 0 then
        vim.diagnostic.setloclist({
            severity = {
                vim.diagnostic.severity.ERROR,
                vim.diagnostic.severity.WARN,
                vim.diagnostic.severity.INFO,
            }
        })
    -- else
    --     vim.cmd.lclose()
    -- end
end, {})

vim.keymap.set("n", "<leader>l", ":ToggleLoclist<CR>")
