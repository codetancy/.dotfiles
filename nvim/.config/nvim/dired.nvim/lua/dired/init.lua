-- Entry point: setup, :Dired / :DiredJump, and taking over directory buffers from netrw.

local api = vim.api
local config = require("dired.config")
local fs = require("dired.fs")
local buffer = require("dired.buffer")
local ui = require("dired.ui")

local M = {}

local pending = {}

local function set_window_options(win)
    for opt, value in pairs({ cursorline = true, wrap = false, spell = false, list = false, foldenable = false }) do
        pcall(api.nvim_set_option_value, opt, value, { scope = "local", win = win })
    end
end

local function wipe_stray(name, keep)
    for _, b in ipairs(api.nvim_list_bufs()) do
        if b ~= keep and api.nvim_buf_is_valid(b) and api.nvim_buf_get_name(b) == name then
            if not vim.bo[b].modified and #vim.fn.win_findbuf(b) == 0 then
                pcall(api.nvim_buf_delete, b, { force = true })
            end
        end
    end
end

-- Shows the dired buffer for `dir` in the current window, creating it if needed.
-- opts.cursor names the entry to put the cursor on.
function M.open(dir, opts)
    opts = opts or {}
    dir = fs.absolute(dir)
    if not fs.is_dir(dir) then
        ui.error("Not a directory: " .. dir)
        return nil
    end
    local buf = buffer.find(dir)
    if buf and api.nvim_get_current_buf() == buf then
        buffer.render(buf, { cursor = opts.cursor })
        return buf
    end
    if not buf then
        buf = api.nvim_create_buf(true, false)
        api.nvim_buf_set_name(buf, dir)
        buffer.attach(buf, fs.absolute(api.nvim_buf_get_name(buf)))
    end
    pending[buf] = opts.cursor or false
    vim.cmd("buffer " .. buf)
    return buf
end

-- Opens the directory of the current file with the cursor on that file
-- (dired-jump). In a dired buffer it goes up one level.
function M.jump()
    local cur = api.nvim_get_current_buf()
    local s = buffer.state[cur]
    if s then
        if s.dir ~= "/" then
            M.open(fs.parent(s.dir), { cursor = fs.basename(s.dir) })
        end
        return
    end
    local name = api.nvim_buf_get_name(cur)
    if name == "" or vim.bo[cur].buftype ~= "" then
        M.open(vim.uv.cwd())
        return
    end
    local path = fs.absolute(name)
    M.open(fs.parent(path), { cursor = fs.basename(path) })
end

local function on_enter(args)
    local buf = args.buf
    local s = buffer.state[buf]
    if s then
        set_window_options(api.nvim_get_current_win())
        if s.wdired then
            return
        end
        local cursor = pending[buf]
        pending[buf] = nil
        buffer.render(buf, { cursor = cursor or nil })
        return
    end
    local name = api.nvim_buf_get_name(buf)
    if name == "" or vim.bo[buf].buftype ~= "" or vim.fn.isdirectory(name) == 0 then
        return
    end
    local dir = fs.absolute(name)
    local existing = buffer.find(dir)
    if existing and existing ~= buf then
        vim.schedule(function()
            if api.nvim_get_current_buf() == buf then
                vim.cmd("buffer " .. existing)
            end
            if api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
                pcall(api.nvim_buf_delete, buf, { force = true })
            end
        end)
        return
    end
    if name ~= dir then
        pcall(api.nvim_buf_set_name, buf, dir)
        wipe_stray(name, buf)
    end
    buffer.attach(buf, fs.absolute(api.nvim_buf_get_name(buf)))
    set_window_options(api.nvim_get_current_win())
    buffer.render(buf)
end

local HIGHLIGHTS = {
    DiredHeader = "Directory",
    DiredDirectory = "Directory",
    DiredSymlink = "DiagnosticHint",
    DiredBrokenLink = "ErrorMsg",
    DiredSymlinkTarget = "Comment",
    DiredExecutable = "String",
    DiredMarked = "WarningMsg",
    DiredFlagged = "ErrorMsg",
    DiredDetails = "LineNr",
}

local function define_highlights()
    for group, link in pairs(HIGHLIGHTS) do
        api.nvim_set_hl(0, group, { link = link, default = true })
    end
end

function M.setup(opts)
    config.set(opts)
    define_highlights()
    if config.options.hijack_netrw then
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
        pcall(api.nvim_clear_autocmds, { group = "FileExplorer" })
    end
    local group = api.nvim_create_augroup("dired", { clear = true })
    if config.options.hijack_netrw then
        api.nvim_create_autocmd("BufEnter", { group = group, pattern = "*", nested = true, callback = on_enter })
        api.nvim_create_autocmd("VimEnter", {
            group = group,
            callback = function()
                on_enter({ buf = api.nvim_get_current_buf() })
            end,
        })
    else
        api.nvim_create_autocmd("BufEnter", {
            group = group,
            pattern = "*",
            callback = function(args)
                if buffer.state[args.buf] then
                    on_enter(args)
                end
            end,
        })
    end
    api.nvim_create_autocmd("FocusGained", {
        group = group,
        callback = function()
            buffer.refresh_all()
        end,
    })
    api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_highlights })
    api.nvim_create_user_command("Dired", function(cmd)
        if cmd.args ~= "" then
            M.open(cmd.args)
        else
            M.jump()
        end
    end, { nargs = "?", complete = "dir", desc = "Open a directory in dired" })
    api.nvim_create_user_command("DiredJump", M.jump, { desc = "Open the current file's directory in dired" })
end

return M
