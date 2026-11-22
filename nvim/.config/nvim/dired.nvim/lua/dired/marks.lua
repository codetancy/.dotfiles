-- Marks: "*" marks a file for an operation, "D" flags it for deletion with x.
-- "." and ".." are never marked.

local api = vim.api
local buffer = require("dired.buffer")
local fs = require("dired.fs")
local ui = require("dired.ui")

local M = {}

local function markable(e)
    return e and e.name ~= "." and e.name ~= ".."
end

-- Rows to act on: the visual selection, else [count] lines from the cursor.
local function rows()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local a, b = vim.fn.line("v"), vim.fn.line(".")
        if a > b then
            a, b = b, a
        end
        vim.cmd("normal! \27")
        return a, b, true
    end
    local row = api.nvim_win_get_cursor(0)[1]
    return row, row + vim.v.count1 - 1, false
end

local function set_rows(buf, char)
    local s = buffer.state[buf]
    local a, b, visual = rows()
    for row = a, b do
        local e = buffer.entry_at(buf, row)
        if markable(e) then
            s.marks[e.name] = char
        end
    end
    buffer.render(buf, { relist = false })
    buffer.set_cursor(0, buf, visual and b or b + 1)
end

function M.mark(buf)
    set_rows(buf, "*")
end

function M.unmark(buf)
    set_rows(buf, nil)
end

function M.flag(buf)
    set_rows(buf, "D")
end

function M.unmark_backward(buf)
    local row = api.nvim_win_get_cursor(0)[1] - 1
    local e = buffer.entry_at(buf, row)
    if markable(e) then
        buffer.state[buf].marks[e.name] = nil
    end
    buffer.render(buf, { relist = false })
    buffer.set_cursor(0, buf, row)
end

function M.toggle(buf)
    local s = buffer.state[buf]
    for _, e in ipairs(s.entries) do
        if markable(e) then
            if s.marks[e.name] == "*" then
                s.marks[e.name] = nil
            elseif s.marks[e.name] == nil then
                s.marks[e.name] = "*"
            end
        end
    end
    buffer.render(buf, { relist = false })
end

function M.unmark_all(buf)
    buffer.state[buf].marks = {}
    buffer.render(buf, { relist = false })
end

local function mark_where(buf, char, pred)
    local s = buffer.state[buf]
    local n = 0
    for _, e in ipairs(s.entries) do
        if markable(e) and pred(e) then
            s.marks[e.name] = char
            n = n + 1
        end
    end
    buffer.render(buf, { relist = false })
    ui.info(string.format("%d %s", n, char == "D" and "flagged" or "marked"))
    return n
end

function M.mark_directories(buf)
    mark_where(buf, "*", fs.is_directory_like)
end

function M.mark_executables(buf)
    mark_where(buf, "*", fs.is_executable)
end

function M.mark_symlinks(buf)
    mark_where(buf, "*", function(e)
        return e.type == "link"
    end)
end

function M.mark_extension(buf)
    local e = buffer.cursor_entry(buf)
    local default = e and e.name:match("%.([^.]+)$") or ""
    local ext = ui.input("Mark extension: ", default)
    if not ext or ext == "" then
        return
    end
    ext = ext:gsub("^%.", "")
    mark_where(buf, "*", function(x)
        return x.name:sub(-(#ext + 1)) == "." .. ext
    end)
end

local function by_regexp(buf, char, prompt)
    local pat = ui.input(prompt)
    if not pat or pat == "" then
        return
    end
    local ok, re = pcall(vim.regex, pat)
    if not ok then
        ui.error("Invalid regexp: " .. pat)
        return
    end
    mark_where(buf, char, function(e)
        return re:match_str(e.name) ~= nil
    end)
end

function M.mark_regexp(buf)
    by_regexp(buf, "*", "Mark names matching (Vim regexp): ")
end

function M.flag_regexp(buf)
    by_regexp(buf, "D", "Flag names matching (Vim regexp): ")
end

function M.mark_containing(buf)
    local pat = ui.input("Mark files containing (ripgrep regexp): ")
    if not pat or pat == "" then
        return
    end
    local s = buffer.state[buf]
    local files = {}
    for _, e in ipairs(s.entries) do
        if markable(e) and e.type == "file" then
            files[#files + 1] = e.name
        end
    end
    if #files == 0 then
        return
    end
    local cmd = { "rg", "--files-with-matches", "--no-messages", "--no-ignore", "--hidden", "-e", pat, "--" }
    vim.list_extend(cmd, files)
    local ok, res = pcall(function()
        return vim.system(cmd, { cwd = s.dir, text = true }):wait()
    end)
    if not ok then
        ui.error("ripgrep (rg) is needed for %g")
        return
    end
    if res.code > 1 then
        ui.error(vim.trim(res.stderr or "rg failed"))
        return
    end
    local hits = {}
    for _, line in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
        hits[(line:gsub("^%./", ""))] = true
    end
    mark_where(buf, "*", function(e)
        return hits[e.name] == true
    end)
end

function M.flag_backups(buf)
    mark_where(buf, "D", function(e)
        return e.name:sub(-1) == "~"
    end)
end

function M.count(buf)
    local marked, flagged = 0, 0
    for _, c in pairs(buffer.state[buf].marks) do
        if c == "*" then
            marked = marked + 1
        else
            flagged = flagged + 1
        end
    end
    ui.info(string.format("%d marked, %d flagged", marked, flagged))
end

return M
