local api = vim.api
local buffer = require("dired.buffer")
local fs = require("dired.fs")
local ui = require("dired.ui")

local M = {}

local function dired()
    return require("dired")
end

function M.open(buf)
    local e = buffer.cursor_entry(buf)
    if not e then
        return
    end
    if e.name == "." then
        return buffer.render(buf)
    end
    if e.name == ".." then
        return M.up(buf)
    end
    if fs.is_directory_like(e) then
        return dired().open(e.path)
    end
    vim.cmd("edit " .. vim.fn.fnameescape(e.path))
end

function M.open_other(buf)
    local e = buffer.cursor_entry(buf)
    if not e or e.name == "." then
        return
    end
    local path = e.name == ".." and fs.parent(buffer.state[buf].dir) or e.path
    local cur = api.nvim_get_current_win()
    local wins = api.nvim_tabpage_list_wins(0)
    if #wins > 1 then
        vim.cmd("wincmd p")
        if api.nvim_get_current_win() == cur then
            vim.cmd("wincmd w")
        end
    else
        vim.cmd("vsplit")
    end
    if fs.is_dir(path) then
        dired().open(path)
    else
        vim.cmd("edit " .. vim.fn.fnameescape(path))
    end
end

function M.up(buf)
    local dir = buffer.state[buf].dir
    if dir == "/" then
        return
    end
    dired().open(fs.parent(dir), { cursor = fs.basename(dir) })
end

function M.quit(buf)
    local alt = vim.fn.bufnr("#")
    if alt > 0 and alt ~= buf and api.nvim_buf_is_valid(alt) and vim.fn.buflisted(alt) == 1 then
        vim.cmd("buffer " .. alt)
        return
    end
    if #api.nvim_tabpage_list_wins(0) > 1 then
        vim.cmd("close")
        return
    end
    for _, b in ipairs(api.nvim_list_bufs()) do
        if b ~= buf and vim.fn.buflisted(b) == 1 and not buffer.state[b] then
            vim.cmd("buffer " .. b)
            return
        end
    end
    ui.info("No other buffer to show")
end

function M.refresh(buf)
    buffer.render(buf)
end

function M.toggle_sort(buf)
    local s = buffer.state[buf]
    s.sort = s.sort == "time" and "name" or "time"
    buffer.render(buf)
end

function M.toggle_details(buf)
    local s = buffer.state[buf]
    s.details = not s.details
    buffer.render(buf, { relist = false })
end

function M.toggle_hidden(buf)
    local s = buffer.state[buf]
    s.hidden = not s.hidden
    buffer.render(buf)
end

local function goto_dir(buf, step)
    local s = buffer.state[buf]
    local row = api.nvim_win_get_cursor(0)[1]
    local i = row - buffer.HEADER + step
    while i >= 1 and i <= #s.entries do
        local e = s.entries[i]
        if fs.is_directory_like(e) and e.name ~= "." and e.name ~= ".." then
            buffer.set_cursor(0, buf, i + buffer.HEADER)
            return
        end
        i = i + step
    end
end

function M.prev_dir(buf)
    goto_dir(buf, -1)
end

function M.next_dir(buf)
    goto_dir(buf, 1)
end

function M.help()
    local maps = require("dired.keymaps").list()
    local width = 0
    for _, m in ipairs(maps) do
        width = math.max(width, vim.fn.strdisplaywidth(m.lhs))
    end
    local lines = {}
    for _, m in ipairs(maps) do
        lines[#lines + 1] = string.format(" %-" .. width .. "s  %s ", m.lhs, m.desc)
    end
    local hbuf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(hbuf, 0, -1, false, lines)
    vim.bo[hbuf].modifiable = false
    vim.bo[hbuf].bufhidden = "wipe"
    local w = 0
    for _, l in ipairs(lines) do
        w = math.max(w, vim.fn.strdisplaywidth(l))
    end
    local h = math.min(#lines, vim.o.lines - 6)
    local win = api.nvim_open_win(hbuf, true, {
        relative = "editor",
        width = w,
        height = h,
        row = math.floor((vim.o.lines - h) / 2) - 1,
        col = math.floor((vim.o.columns - w) / 2),
        border = "rounded",
        title = " dired keys ",
        style = "minimal",
    })
    for _, key in ipairs({ "q", "<Esc>", "?" }) do
        vim.keymap.set("n", key, function()
            api.nvim_win_close(win, true)
        end, { buffer = hbuf, nowait = true })
    end
end

return M
