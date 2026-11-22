-- WDired: the buffer becomes the list of names; edit them with any Vim command
-- and :w renames the files. Only renames: adding, removing, joining or
-- reordering lines is refused at commit time.

local api = vim.api
local buffer = require("dired.buffer")
local fs = require("dired.fs")
local ui = require("dired.ui")

local M = {}

local ns = api.nvim_create_namespace("dired_wdired")
local ns_header = api.nvim_create_namespace("dired_wdired_header")

local function leave(buf)
    local s = buffer.state[buf]
    s.wdired = nil
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    api.nvim_buf_clear_namespace(buf, ns_header, 0, -1)
    pcall(api.nvim_del_augroup_by_name, "dired_wdired_" .. buf)
    for _, lhs in ipairs({ "<C-c><C-c>", "<C-c><C-k>", "<C-c><Esc>" }) do
        pcall(vim.keymap.del, "n", lhs, { buffer = buf })
    end
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].modified = false
    require("dired.keymaps").apply(buf)
end

function M.enter(buf)
    local s = buffer.state[buf]
    if s.wdired then
        return
    end
    local entries = {}
    for _, e in ipairs(s.entries) do
        if e.name ~= "." and e.name ~= ".." then
            if e.name:find("%c") then
                ui.error("WDired cannot edit names with control characters (" .. vim.inspect(e.name) .. "); use R")
                return
            end
            entries[#entries + 1] = e
        end
    end
    if #entries == 0 then
        ui.info("Nothing to rename")
        return
    end
    local cursor = buffer.cursor_entry(buf)
    s.wdired = { by_mark = {}, count = #entries }
    require("dired.keymaps").clear(buf)

    local names = {}
    for i, e in ipairs(entries) do
        names[i] = e.name
    end
    local bo = vim.bo[buf]
    api.nvim_buf_clear_namespace(buf, buffer.ns, 0, -1)
    bo.modifiable = true
    local levels = bo.undolevels
    bo.undolevels = -1
    api.nvim_buf_set_lines(buf, 0, -1, false, names)
    bo.undolevels = levels
    for i, e in ipairs(entries) do
        local id = api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { right_gravity = false })
        s.wdired.by_mark[id] = e
    end
    api.nvim_buf_set_extmark(buf, ns_header, 0, 0, {
        virt_lines = { { { "WDired " .. s.dir .. "   :w renames   <C-c><C-k> aborts", "DiredHeader" } } },
        virt_lines_above = true,
    })
    bo.buftype = "acwrite"
    bo.modified = false

    local group = api.nvim_create_augroup("dired_wdired_" .. buf, { clear = true })
    api.nvim_create_autocmd("BufWriteCmd", {
        group = group,
        buffer = buf,
        callback = function()
            M.commit(buf)
        end,
    })
    vim.keymap.set("n", "<C-c><C-c>", function()
        M.commit(buf)
    end, { buffer = buf, desc = "dired: apply renames" })
    for _, lhs in ipairs({ "<C-c><C-k>", "<C-c><Esc>" }) do
        vim.keymap.set("n", lhs, function()
            M.abort(buf)
        end, { buffer = buf, desc = "dired: abort wdired" })
    end

    local row = 1
    if cursor then
        for i, e in ipairs(entries) do
            if e.name == cursor.name then
                row = i
            end
        end
    end
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        api.nvim_win_set_cursor(win, { row, 0 })
        if row == 1 then
            api.nvim_win_call(win, function()
                vim.fn.winrestview({ topfill = 1 })
            end)
        end
    end
end

function M.abort(buf)
    local s = buffer.state[buf]
    if not s or not s.wdired then
        return
    end
    leave(buf)
    buffer.render(buf)
end

-- Reads the edited buffer into { entry, new_name } changes, or returns nil and an error.
local function collect(buf)
    local s = buffer.state[buf]
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    local rows = {}
    for _, m in ipairs(api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})) do
        local row = m[2]
        rows[row] = rows[row] or {}
        table.insert(rows[row], m[1])
    end
    local broken = "Lines were added, removed, joined or moved. WDired only renames in place; undo with u or abort with <C-c><C-k>."
    if #lines ~= s.wdired.count then
        return nil, broken
    end
    local changes, seen = {}, {}
    for row = 0, #lines - 1 do
        local ids = rows[row]
        if not ids or #ids ~= 1 or seen[ids[1]] then
            return nil, broken
        end
        seen[ids[1]] = true
        local e = s.wdired.by_mark[ids[1]]
        local new = lines[row + 1]
        if new ~= e.name then
            local trimmed = new:gsub("/+$", "")
            if trimmed == "" or trimmed == "." or trimmed == ".." or trimmed:find("%z") then
                return nil, "Invalid name on line " .. (row + 1) .. ": '" .. new .. "'"
            end
            local dst = fs.absolute(trimmed, s.dir)
            if dst ~= e.path then
                changes[#changes + 1] = { entry = e, dst = dst }
            end
        end
    end
    return changes
end

local function validate(changes)
    local sources, targets = {}, {}
    for _, c in ipairs(changes) do
        sources[c.entry.path] = true
    end
    for _, c in ipairs(changes) do
        if targets[c.dst] then
            return "Two files would be renamed to " .. c.dst
        end
        targets[c.dst] = true
        if fs.is_real_dir(c.entry.path) and fs.is_ancestor(c.entry.path, c.dst) then
            return "Cannot move " .. c.entry.name .. " into itself"
        end
        if fs.exists(c.dst) and not sources[c.dst] and not fs.same_file(c.entry.path, c.dst) then
            return c.dst .. " already exists"
        end
    end
    return nil
end

-- Runs the renames. When a target is also a source (a swap or a cycle), every
-- file first moves to a temporary name. On failure, completed steps are undone.
local function execute(changes)
    local sources = {}
    for _, c in ipairs(changes) do
        sources[c.entry.path] = true
    end
    local needs_temp = false
    for _, c in ipairs(changes) do
        if sources[c.dst] then
            needs_temp = true
        end
    end
    local steps = {}
    if needs_temp then
        local stamp = tostring(vim.uv.hrtime())
        for i, c in ipairs(changes) do
            local tmp = fs.join(fs.parent(c.entry.path), ".dired-tmp-" .. stamp .. "-" .. i)
            steps[#steps + 1] = { c.entry.path, tmp }
            c.tmp = tmp
        end
        for _, c in ipairs(changes) do
            steps[#steps + 1] = { c.tmp, c.dst }
        end
    else
        for _, c in ipairs(changes) do
            steps[#steps + 1] = { c.entry.path, c.dst }
        end
    end
    local done = {}
    for _, step in ipairs(steps) do
        local parent = fs.parent(step[2])
        local ok, err = true, nil
        if not fs.is_dir(parent) then
            ok, err = fs.mkdir_p(parent)
        end
        if ok then
            ok, err = fs.rename(step[1], step[2])
        end
        if not ok then
            for i = #done, 1, -1 do
                fs.rename(done[i][2], done[i][1])
            end
            return nil, step[1] .. " -> " .. step[2] .. ": " .. tostring(err)
        end
        done[#done + 1] = step
    end
    return true
end

function M.commit(buf)
    local s = buffer.state[buf]
    if not s or not s.wdired then
        return
    end
    local changes, err = collect(buf)
    if not changes then
        ui.error(err)
        return
    end
    err = validate(changes)
    if err then
        ui.error(err)
        return
    end
    local cursor_row = api.nvim_win_get_cursor(0)[1]
    local cursor_name = api.nvim_buf_get_lines(buf, cursor_row - 1, cursor_row, false)[1]
    if #changes > 0 then
        local ok, e = execute(changes)
        if not ok then
            ui.error("Renames rolled back: " .. e)
            return
        end
        local ops = require("dired.ops")
        for _, c in ipairs(changes) do
            s.marks[c.entry.name] = nil
            if ops.follow_rename then
                ops.follow_rename(c.entry.path, c.dst)
            end
        end
    end
    leave(buf)
    buffer.refresh_all(buf, cursor_name and cursor_name:gsub("/+$", "") or nil)
    ui.info(string.format("Renamed %d file%s", #changes, #changes == 1 and "" or "s"))
end

return M
