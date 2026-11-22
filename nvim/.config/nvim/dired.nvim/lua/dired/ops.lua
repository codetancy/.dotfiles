-- File operations on the marked files (or the file on the cursor line).

local api = vim.api
local buffer = require("dired.buffer")
local config = require("dired.config")
local fs = require("dired.fs")
local ui = require("dired.ui")

local M = {}

local function targets(buf)
    local entries, from_marks = buffer.targets(buf)
    if #entries == 0 then
        ui.info("No file on this line")
    end
    return entries, from_marks
end

local function describe(entries)
    if #entries == 1 then
        return entries[1].name
    end
    return #entries .. " files"
end

local function dir_slash(dir)
    return dir == "/" and "/" or dir .. "/"
end

-- With dwim_target, the directory of another dired window in this tab.
local function default_dir(buf)
    if config.options.dwim_target then
        for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
            local b = api.nvim_win_get_buf(win)
            if b ~= buf and buffer.state[b] then
                return buffer.state[b].dir
            end
        end
    end
    return buffer.state[buf].dir
end

local function unmark(buf, entries)
    local marks = buffer.state[buf].marks
    for _, e in ipairs(entries) do
        marks[e.name] = nil
    end
end

local function report(verb, done, errors)
    if #errors > 0 then
        ui.error(string.format("%s %d, failed %d:\n%s", verb, done, #errors, table.concat(errors, "\n")))
    else
        ui.info(string.format("%s %d file%s", verb, done, done == 1 and "" or "s"))
    end
end

local function under(old, old_real, path)
    return fs.is_ancestor(old, path) and old or (fs.is_ancestor(old_real, path) and old_real) or nil
end

-- Buffers visiting `old` (or files under it), and dired buffers listing it,
-- follow a rename to `new`.
local function follow_rename(old, new)
    local old_real, new_real = fs.real(old), fs.real(new)
    for b, st in pairs(buffer.state) do
        local base = api.nvim_buf_is_valid(b) and under(old, old_real, st.dir)
        if base then
            pcall(api.nvim_buf_set_name, b, new_real .. st.dir:sub(#base + 1))
            st.dir = fs.absolute(api.nvim_buf_get_name(b))
        end
    end
    for _, b in ipairs(api.nvim_list_bufs()) do
        local name = api.nvim_buf_get_name(b)
        local base = name ~= "" and not buffer.state[b] and under(old, old_real, name)
        if base then
            pcall(api.nvim_buf_set_name, b, new_real .. name:sub(#base + 1))
            if not vim.bo[b].modified and api.nvim_buf_is_loaded(b) then
                api.nvim_buf_call(b, function()
                    pcall(vim.cmd, "silent edit!")
                end)
            end
        end
    end
end

M.follow_rename = follow_rename

local function close_deleted(path, real)
    for b, st in pairs(buffer.state) do
        if api.nvim_buf_is_valid(b) and under(path, real, st.dir) and #vim.fn.win_findbuf(b) == 0 then
            pcall(api.nvim_buf_delete, b, { force = true })
        end
    end
    for _, b in ipairs(api.nvim_list_bufs()) do
        local name = api.nvim_buf_get_name(b)
        if name ~= "" and not buffer.state[b] and under(path, real, name) and not vim.bo[b].modified then
            pcall(api.nvim_buf_delete, b, { force = false })
        end
    end
end

-- Asks for a destination and pairs each source with its target path.
-- Several sources, a trailing "/" or an existing directory mean "into that directory".
local function destination(buf, entries, verb)
    local prompt = string.format("%s %s to: ", verb, describe(entries))
    local input = ui.input(prompt, dir_slash(default_dir(buf)), "file")
    if not input or vim.trim(input) == "" then
        return nil
    end
    local dir = buffer.state[buf].dir
    local into = input:sub(-1) == "/"
    local dest = fs.absolute(input, dir)
    if #entries > 1 or into then
        if not fs.is_dir(dest) then
            if fs.exists(dest) then
                ui.error("Not a directory: " .. dest)
                return nil
            end
            if not ui.y_or_n("Create directory " .. dest .. "? ") then
                return nil
            end
            local ok, err = fs.mkdir_p(dest)
            if not ok then
                ui.error(err)
                return nil
            end
        end
        into = true
    elseif fs.is_dir(dest) then
        into = true
    end
    local pairs_ = {}
    for _, e in ipairs(entries) do
        pairs_[#pairs_ + 1] = { entry = e, src = e.path, dst = into and fs.join(dest, e.name) or dest }
    end
    return pairs_
end

-- Drops impossible pairs and asks before overwriting. Returns the pairs to run
-- and the errors found; nil when the user quits.
local function resolve(pairs_, verb)
    local out, errors = {}, {}
    local all = false
    for _, p in ipairs(pairs_) do
        local src_dir = fs.is_real_dir(p.src)
        if p.src == p.dst then
            errors[#errors + 1] = p.entry.name .. ": source and target are the same"
        elseif src_dir and fs.is_ancestor(p.src, p.dst) then
            errors[#errors + 1] = p.entry.name .. ": cannot " .. verb:lower() .. " a directory into itself"
        elseif verb == "Rename" and fs.same_file(p.src, p.dst) then
            out[#out + 1] = p
        elseif fs.exists(p.dst) then
            if fs.same_file(p.src, p.dst) then
                errors[#errors + 1] = p.entry.name .. ": source and target are the same file"
            elseif fs.is_real_dir(p.dst) then
                errors[#errors + 1] = p.dst .. " exists and is a directory"
            elseif src_dir then
                errors[#errors + 1] = p.dst .. " exists and is not a directory"
            else
                local answer = all and "y" or ui.choice("Overwrite " .. p.dst .. "? [y/n/!/q] ", { "y", "n", "!", "q" })
                if answer == nil or answer == "q" then
                    return nil
                end
                if answer == "!" then
                    all = true
                end
                if answer ~= "n" then
                    p.overwrite = true
                    out[#out + 1] = p
                end
            end
        else
            out[#out + 1] = p
        end
    end
    return out, errors
end

local function finish(buf, verb, done, errors, cursor_path)
    local dir = buffer.state[buf].dir
    local cursor = cursor_path and fs.parent(cursor_path) == dir and fs.basename(cursor_path) or nil
    buffer.refresh_all(buf, cursor)
    report(verb, done, errors)
end

local function transfer(buf, verb, past, run)
    local entries = targets(buf)
    if #entries == 0 then
        return
    end
    local pairs_ = destination(buf, entries, verb)
    if not pairs_ then
        return
    end
    local todo, errors = resolve(pairs_, verb)
    if not todo then
        return
    end
    local done, ok_entries, last = 0, {}, nil
    local recursive_all = false
    for _, p in ipairs(todo) do
        local skip = false
        if verb == "Copy" and fs.is_real_dir(p.src) and not recursive_all then
            local answer = ui.choice("Recursively copy " .. p.entry.name .. "? [y/a/n/q] ", { "y", "a", "n", "q" })
            if answer == nil or answer == "q" then
                break
            end
            recursive_all = answer == "a"
            skip = answer == "n"
        end
        if not skip then
            local ok, err = true, nil
            if p.overwrite and verb ~= "Rename" then
                ok, err = fs.delete(p.dst)
            end
            if ok then
                ok, err = run(p)
            end
            if ok then
                done = done + 1
                ok_entries[#ok_entries + 1] = p.entry
                last = p.dst
            else
                errors[#errors + 1] = p.entry.name .. ": " .. tostring(err)
            end
        end
    end
    unmark(buf, ok_entries)
    finish(buf, past, done, errors, #todo == 1 and last or nil)
end

function M.copy(buf)
    transfer(buf, "Copy", "Copied", function(p)
        return fs.copy(p.src, p.dst)
    end)
end

function M.rename(buf)
    transfer(buf, "Rename", "Renamed", function(p)
        local ok, err = fs.rename(p.src, p.dst)
        if ok then
            follow_rename(p.src, p.dst)
        end
        return ok, err
    end)
end

function M.symlink(buf)
    transfer(buf, "Symlink", "Linked", function(p)
        return fs.symlink(p.src, p.dst)
    end)
end

function M.relsymlink(buf)
    transfer(buf, "Relative symlink", "Linked", function(p)
        return fs.symlink(fs.relpath(fs.parent(p.dst), p.src), p.dst)
    end)
end

function M.hardlink(buf)
    transfer(buf, "Hardlink", "Linked", function(p)
        return fs.hardlink(p.src, p.dst)
    end)
end

local function delete_entries(buf, entries)
    if #entries == 0 then
        return
    end
    local names = {}
    for i, e in ipairs(entries) do
        if i > 8 then
            names[#names + 1] = "..."
            break
        end
        names[#names + 1] = e.name
    end
    local prompt = #entries == 1 and ("Delete " .. entries[1].name .. "? ")
        or string.format("Delete %d files (%s)? ", #entries, table.concat(names, ", "))
    if not ui.yes_or_no(prompt) then
        return
    end
    local done, errors, deleted, all = 0, {}, {}, false
    for _, e in ipairs(entries) do
        local skip = false
        if e.type == "directory" and not fs.is_empty_dir(e.path) and not all then
            local answer = ui.choice("Recursively delete " .. e.name .. "? [y/a/n/q] ", { "y", "a", "n", "q" })
            if answer == nil or answer == "q" then
                break
            end
            all = answer == "a"
            skip = answer == "n"
        end
        if not skip then
            local real = fs.real(e.path)
            local ok, err = fs.delete(e.path)
            if ok then
                done = done + 1
                deleted[#deleted + 1] = e
                close_deleted(e.path, real)
            else
                errors[#errors + 1] = e.name .. ": " .. tostring(err)
            end
        end
    end
    unmark(buf, deleted)
    buffer.refresh_all()
    report("Deleted", done, errors)
end

function M.delete_flagged(buf)
    local s = buffer.state[buf]
    local entries = {}
    for _, e in ipairs(s.entries) do
        if s.marks[e.name] == "D" then
            entries[#entries + 1] = e
        end
    end
    if #entries == 0 then
        ui.info("No files flagged for deletion (flag with d)")
        return
    end
    delete_entries(buf, entries)
end

function M.delete(buf)
    delete_entries(buf, (targets(buf)))
end

function M.mkdir(buf)
    local dir = buffer.state[buf].dir
    local input = ui.input("Create directory: ", dir_slash(dir), "dir")
    if not input or vim.trim(input) == "" then
        return
    end
    local path = fs.absolute(input, dir)
    if fs.exists(path) then
        ui.error("Already exists: " .. path)
        return
    end
    local ok, err = fs.mkdir_p(path)
    if not ok then
        ui.error(err)
        return
    end
    local cursor
    if fs.is_ancestor(dir, path) and path ~= dir then
        cursor = vim.split(path:sub(#dir_slash(dir) + 1), "/")[1]
    end
    buffer.refresh_all(buf, cursor)
end

local function run_on_paths(buf, cmd, entries)
    local argv = vim.deepcopy(cmd)
    argv[#argv + 1] = "--"
    for _, e in ipairs(entries) do
        argv[#argv + 1] = e.path
    end
    local res = vim.system(argv, { text = true }):wait()
    buffer.refresh_all()
    if res.code ~= 0 then
        ui.error(vim.trim(res.stderr ~= "" and res.stderr or (cmd[1] .. " failed")))
    end
end

function M.chmod(buf)
    local entries = targets(buf)
    if #entries == 0 then
        return
    end
    local mode = ui.input("Change mode of " .. describe(entries) .. " to: ")
    if not mode or vim.trim(mode) == "" then
        return
    end
    run_on_paths(buf, { "chmod", vim.trim(mode) }, entries)
end

function M.touch(buf)
    local entries = targets(buf)
    if #entries == 0 then
        return
    end
    local stamp = ui.input("Timestamp for " .. describe(entries) .. " ([[CC]YY]MMDDhhmm[.ss], empty for now): ")
    if stamp == nil then
        return
    end
    stamp = vim.trim(stamp)
    run_on_paths(buf, stamp == "" and { "touch" } or { "touch", "-t", stamp }, entries)
end

local function has_word(cmd, ch)
    return (" " .. cmd .. " "):find("%s" .. vim.pesc(ch) .. "%s") ~= nil
end

local function substitute_word(cmd, ch, value)
    local padded = " " .. cmd .. " "
    local pattern = "(%s)" .. vim.pesc(ch) .. "(%s)"
    local repl = "%1" .. value:gsub("%%", "%%%%") .. "%2"
    padded = padded:gsub(pattern, repl)
    padded = padded:gsub(pattern, repl)
    return padded:sub(2, -2)
end

-- Dired's rules: a lone `*` runs the command once with every file in its place;
-- a lone `?` runs it once per file with that file in its place; otherwise it
-- runs once per file with the file appended.
function M.shell_commands(cmd, names)
    local quoted = {}
    for i, n in ipairs(names) do
        quoted[i] = vim.fn.shellescape(n)
    end
    if has_word(cmd, "*") then
        return { substitute_word(cmd, "*", table.concat(quoted, " ")) }
    end
    local out = {}
    for _, q in ipairs(quoted) do
        if has_word(cmd, "?") then
            out[#out + 1] = substitute_word(cmd, "?", q)
        else
            out[#out + 1] = cmd .. " " .. q
        end
    end
    return out
end

local function show_output(title, text)
    text = vim.trim(text or "")
    if text == "" then
        return
    end
    local lines = vim.split(text, "\n")
    if #lines == 1 then
        ui.info(lines[1])
        return
    end
    local name = "dired://" .. title
    local obuf
    for _, b in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_get_name(b) == name then
            obuf = b
        end
    end
    if not obuf then
        obuf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_name(obuf, name)
    end
    vim.bo[obuf].modifiable = true
    api.nvim_buf_set_lines(obuf, 0, -1, false, lines)
    vim.bo[obuf].modifiable = false
    if #vim.fn.win_findbuf(obuf) == 0 then
        local cur = api.nvim_get_current_win()
        vim.cmd("botright " .. math.min(#lines, 12) .. "split")
        api.nvim_win_set_buf(0, obuf)
        api.nvim_set_current_win(cur)
    end
end

local function shell(buf, async)
    local entries = targets(buf)
    if #entries == 0 then
        return
    end
    local cmd = ui.input((async and "& " or "! ") .. "on " .. describe(entries) .. ": ", "", "shellcmd")
    if not cmd or vim.trim(cmd) == "" then
        return
    end
    local names = {}
    for i, e in ipairs(entries) do
        names[i] = e.name
    end
    local script = table.concat(M.shell_commands(cmd, names), "\n")
    local dir = buffer.state[buf].dir
    if async then
        vim.system({ "sh", "-c", script }, { cwd = dir, text = true }, function(res)
            vim.schedule(function()
                buffer.refresh_all()
                show_output("shell-output", (res.stdout or "") .. (res.stderr or ""))
                ui.info("& finished with exit code " .. res.code .. ": " .. cmd)
            end)
        end)
        return
    end
    local res = vim.system({ "sh", "-c", script }, { cwd = dir, text = true }):wait()
    buffer.refresh_all()
    show_output("shell-output", (res.stdout or "") .. (res.stderr or ""))
    if res.code ~= 0 then
        ui.error("Exit code " .. res.code .. ": " .. cmd)
    end
end

function M.shell(buf)
    shell(buf, false)
end

function M.async_shell(buf)
    shell(buf, true)
end

-- Renames in place, confirming each when `confirm` is set.
local function rename_in_place(buf, plan, confirm)
    local dir = buffer.state[buf].dir
    local all = not confirm
    local done, errors, last = 0, {}, nil
    for _, item in ipairs(plan) do
        local e, new = item[1], item[2]
        local dst = fs.join(dir, new)
        if new == "" or new:find("/", 1, true) then
            errors[#errors + 1] = e.name .. ": invalid new name '" .. new .. "'"
        elseif fs.exists(dst) and not fs.same_file(e.path, dst) then
            errors[#errors + 1] = e.name .. ": " .. new .. " already exists"
        else
            local answer = all and "y"
                or ui.choice("Rename " .. e.name .. " to " .. new .. "? [y/n/!/q] ", { "y", "n", "!", "q" })
            if answer == nil or answer == "q" then
                break
            end
            if answer == "!" then
                all = true
            end
            if answer ~= "n" then
                local ok, err = fs.rename(e.path, dst)
                if ok then
                    follow_rename(e.path, dst)
                    buffer.state[buf].marks[e.name] = nil
                    done = done + 1
                    last = new
                else
                    errors[#errors + 1] = e.name .. ": " .. tostring(err)
                end
            end
        end
    end
    buffer.refresh_all(buf, done == 1 and last or nil)
    report("Renamed", done, errors)
end

function M.rename_regexp(buf)
    local entries = targets(buf)
    if #entries == 0 then
        return
    end
    local pat = ui.input("Rename from (Vim regexp): ")
    if not pat or pat == "" then
        return
    end
    local ok = pcall(vim.regex, pat)
    if not ok then
        ui.error("Invalid regexp: " .. pat)
        return
    end
    local rep = ui.input("Rename '" .. pat .. "' to: ")
    if rep == nil then
        return
    end
    local plan = {}
    for _, e in ipairs(entries) do
        local new = vim.fn.substitute(e.name, pat, rep, "")
        if new ~= e.name then
            plan[#plan + 1] = { e, new }
        end
    end
    if #plan == 0 then
        ui.info("No names match " .. pat)
        return
    end
    rename_in_place(buf, plan, true)
end

local function change_case(buf, fn)
    local entries = targets(buf)
    local plan = {}
    for _, e in ipairs(entries) do
        local new = fn(e.name)
        if new ~= e.name then
            plan[#plan + 1] = { e, new }
        end
    end
    if #plan > 0 then
        rename_in_place(buf, plan, false)
    end
end

function M.upcase(buf)
    change_case(buf, string.upper)
end

function M.downcase(buf)
    change_case(buf, string.lower)
end

function M.diff(buf)
    local e = buffer.cursor_entry(buf)
    if not e or fs.is_directory_like(e) then
        ui.info("Put the cursor on a file to diff")
        return
    end
    local other
    local s = buffer.state[buf]
    local marked = {}
    for _, x in ipairs(s.entries) do
        if s.marks[x.name] == "*" and x.name ~= e.name then
            marked[#marked + 1] = x
        end
    end
    if #marked == 1 then
        other = marked[1].path
    else
        local input = ui.input("Diff " .. e.name .. " with: ", dir_slash(s.dir), "file")
        if not input or vim.trim(input) == "" then
            return
        end
        other = fs.absolute(input, s.dir)
    end
    vim.cmd("tabedit " .. vim.fn.fnameescape(other))
    vim.cmd("vertical diffsplit " .. vim.fn.fnameescape(e.path))
end

function M.open_external(buf)
    for _, e in ipairs((targets(buf))) do
        vim.ui.open(e.path)
    end
end

function M.find_marked(buf)
    local files = {}
    for _, e in ipairs((targets(buf))) do
        if not fs.is_directory_like(e) then
            files[#files + 1] = e.path
        end
    end
    if #files == 0 then
        return
    end
    for i = 2, #files do
        vim.cmd("badd " .. vim.fn.fnameescape(files[i]))
    end
    vim.cmd("edit " .. vim.fn.fnameescape(files[1]))
    if #files > 1 then
        ui.info(string.format("Opened %d files; :ls lists them", #files))
    end
end

local function copy_text(text)
    vim.fn.setreg('"', text)
    pcall(vim.fn.setreg, "+", text)
    ui.info(text)
end

function M.copy_names(buf)
    local names = {}
    for _, e in ipairs((targets(buf))) do
        names[#names + 1] = e.name
    end
    if #names > 0 then
        copy_text(table.concat(names, " "))
    end
end

function M.copy_paths(buf)
    local paths = {}
    for _, e in ipairs((targets(buf))) do
        paths[#paths + 1] = e.path
    end
    if #paths > 0 then
        copy_text(table.concat(paths, " "))
    end
end

function M.file_type(buf)
    local e = buffer.cursor_entry(buf)
    if not e then
        return
    end
    local res = vim.system({ "file", "-b", e.path }, { text = true }):wait()
    ui.info(e.name .. ": " .. vim.trim(res.stdout or ""))
end

return M
