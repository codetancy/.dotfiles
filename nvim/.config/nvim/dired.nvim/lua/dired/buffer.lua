-- Dired buffers: per-buffer state, rendering, cursor placement and lookup of
-- the entry on a line. A dired buffer is named after its directory's absolute path.

local api = vim.api
local config = require("dired.config")
local fs = require("dired.fs")
local render = require("dired.render")

local M = {}

M.state = {}
M.ns = api.nvim_create_namespace("dired")
M.HEADER = 2

function M.find(dir)
    local key = fs.real(dir)
    for buf, s in pairs(M.state) do
        if api.nvim_buf_is_valid(buf) and (s.dir == dir or fs.real(s.dir) == key) then
            return buf
        end
    end
    return nil
end

function M.attach(buf, dir)
    local o = config.options
    M.state[buf] = {
        dir = dir,
        marks = {},
        entries = {},
        name_cols = {},
        sort = o.sort,
        details = o.details,
        hidden = o.show_hidden,
    }
    local bo = vim.bo[buf]
    bo.buftype = "nofile"
    bo.bufhidden = "hide"
    bo.swapfile = false
    bo.modifiable = false
    vim.b[buf].completion = false
    bo.filetype = "dired"
    require("dired.keymaps").apply(buf)
    api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
            M.state[buf] = nil
        end,
    })
end

local function sorted(entries, s)
    local dots, rest = {}, {}
    for _, e in ipairs(entries) do
        if e.name == ".." or (e.name == "." and s.hidden) then
            dots[#dots + 1] = e
        elseif e.name ~= "." and (s.hidden or e.name:sub(1, 1) ~= ".") then
            rest[#rest + 1] = e
        end
    end
    table.sort(dots, function(a, b)
        return a.name < b.name
    end)
    local dirs_first = config.options.dirs_first
    table.sort(rest, function(a, b)
        if dirs_first then
            local da, db = fs.is_directory_like(a), fs.is_directory_like(b)
            if da ~= db then
                return da
            end
        end
        if s.sort == "time" and a.mtime ~= b.mtime then
            return a.mtime > b.mtime
        end
        local la, lb = a.name:lower(), b.name:lower()
        if la ~= lb then
            return la < lb
        end
        return a.name < b.name
    end)
    vim.list_extend(dots, rest)
    return dots
end

function M.entry_at(buf, row)
    local s = M.state[buf]
    return s and s.entries[row - M.HEADER] or nil
end

function M.cursor_entry(buf)
    return M.entry_at(buf, api.nvim_win_get_cursor(0)[1])
end

function M.row_of(buf, name)
    for i, e in ipairs(M.state[buf].entries) do
        if e.name == name then
            return i + M.HEADER
        end
    end
    return nil
end

function M.set_cursor(win, buf, row)
    local s = M.state[buf]
    local last = api.nvim_buf_line_count(buf)
    row = math.max(1, math.min(row, last))
    local col = s.name_cols[row - M.HEADER] or 0
    api.nvim_win_set_cursor(win, { row, col })
end

local function first_file_row(buf)
    local s = M.state[buf]
    for i, e in ipairs(s.entries) do
        if e.name ~= "." and e.name ~= ".." then
            return i + M.HEADER
        end
    end
    return math.min(M.HEADER + 1, api.nvim_buf_line_count(buf))
end

function M.write_lines(buf, lines)
    local bo = vim.bo[buf]
    local levels = bo.undolevels
    bo.modifiable = true
    bo.undolevels = -1
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    bo.undolevels = levels
    bo.modifiable = false
    bo.modified = false
end

-- Re-reads the directory (unless opts.relist == false) and redraws.
-- opts.cursor names the entry to put the cursor on in every window showing the buffer.
function M.render(buf, opts)
    opts = opts or {}
    local s = M.state[buf]
    if not s or s.wdired then
        return
    end
    local remembered = {}
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        local row = api.nvim_win_get_cursor(win)[1]
        local e = M.entry_at(buf, row)
        remembered[win] = { name = e and e.name, row = row, fresh = #s.entries == 0 }
    end
    if opts.relist ~= false then
        local entries, err = fs.list(s.dir)
        if not entries then
            require("dired.ui").error("Cannot read " .. s.dir .. ": " .. tostring(err))
            entries = {}
        end
        s.entries = sorted(entries, s)
        local present = {}
        for _, e in ipairs(s.entries) do
            present[e.name] = true
        end
        for name in pairs(s.marks) do
            if not present[name] then
                s.marks[name] = nil
            end
        end
    end
    local lines, hls, name_cols = render.build(s)
    s.name_cols = name_cols
    M.write_lines(buf, lines)
    api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    for _, h in ipairs(hls) do
        api.nvim_buf_set_extmark(buf, M.ns, h[1], h[2], { end_col = h[3], hl_group = h[4], priority = 150 })
    end
    for win, r in pairs(remembered) do
        local row = opts.cursor and M.row_of(buf, opts.cursor)
        if not row and r.name and not r.fresh then
            row = M.row_of(buf, r.name)
        end
        if not row then
            row = r.fresh and first_file_row(buf) or r.row
        end
        M.set_cursor(win, buf, row)
    end
end

-- Redraws every dired buffer: visible ones now, hidden ones on their next BufEnter.
function M.refresh_all(cursor_buf, cursor_name)
    for buf, s in pairs(M.state) do
        if api.nvim_buf_is_valid(buf) and not s.wdired then
            if #vim.fn.win_findbuf(buf) > 0 then
                M.render(buf, { cursor = buf == cursor_buf and cursor_name or nil })
            end
        end
    end
end

-- Marked entries in display order, else the entry under the cursor.
-- Returns the entries and whether they came from marks.
function M.targets(buf)
    local s = M.state[buf]
    local out = {}
    for _, e in ipairs(s.entries) do
        if s.marks[e.name] == "*" then
            out[#out + 1] = e
        end
    end
    if #out > 0 then
        return out, true
    end
    local e = M.cursor_entry(buf)
    if e and e.name ~= "." and e.name ~= ".." then
        return { e }, false
    end
    return {}, false
end

return M
