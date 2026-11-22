-- Headless test suite: nvim --headless -u NONE -l tests/run.lua
-- Builds a scratch tree per test and drives dired through its keys, with
-- every prompt answered from a queue.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.o.hidden = true
vim.o.swapfile = false
vim.o.shortmess = vim.o.shortmess .. "F"

local api = vim.api
local uv = vim.uv
local dired = require("dired")
dired.setup({})
local ui = require("dired.ui")
local buffer = require("dired.buffer")
local fs = require("dired.fs")
local ops = require("dired.ops")

local answers, infos, errors, prompts = {}, {}, {}, {}
local function answer(prompt)
    prompts[#prompts + 1] = prompt
    if #answers == 0 then
        error("unexpected prompt: " .. prompt)
    end
    local a = table.remove(answers, 1)
    return a
end
ui.input = function(prompt)
    return answer(prompt)
end
ui.choice = function(prompt)
    return answer(prompt)
end
ui.yes_or_no = function(prompt)
    return answer(prompt) == "yes"
end
ui.y_or_n = function(prompt)
    return answer(prompt) == "y"
end
ui.info = function(m)
    infos[#infos + 1] = m
end
ui.error = function(m)
    errors[#errors + 1] = m
end

local function write(path, text)
    vim.fn.mkdir(fs.parent(path), "p")
    local f = assert(io.open(path, "w"))
    f:write(text or "")
    f:close()
end

local function read(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local s = f:read("*a")
    f:close()
    return s
end

local function press(keys)
    api.nvim_feedkeys(vim.keycode(keys), "mx", false)
end

local function eq(a, b, msg)
    if not vim.deep_equal(a, b) then
        error((msg or "values differ") .. "\n  expected: " .. vim.inspect(b) .. "\n  actual:   " .. vim.inspect(a), 2)
    end
end

local function ok(v, msg)
    if not v then
        error(msg or "expected true", 2)
    end
end

local function names(buf)
    local out = {}
    for _, e in ipairs(buffer.state[buf].entries) do
        out[#out + 1] = e.name
    end
    return out
end

local function cursor_name(buf)
    local e = buffer.cursor_entry(buf)
    return e and e.name
end

local function goto_name(buf, name)
    local row = buffer.row_of(buf, name)
    assert(row, "no entry " .. name)
    buffer.set_cursor(0, buf, row)
end

local tmp
local function setup_tree()
    for _, b in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_valid(b) and b ~= api.nvim_get_current_buf() then
            pcall(api.nvim_buf_delete, b, { force = true })
        end
    end
    vim.cmd("enew!")
    vim.cmd("silent! only")
    tmp = fs.absolute(vim.fn.tempname())
    vim.fn.mkdir(tmp, "p")
    tmp = uv.fs_realpath(tmp)
    write(tmp .. "/b.txt", "bee\n")
    write(tmp .. "/a.txt", "alpha\nneedle here\n")
    write(tmp .. "/C.md", "# c\n")
    write(tmp .. "/.hidden", "h\n")
    write(tmp .. "/sub/inner.txt", "inner needle\n")
    write(tmp .. "/zdir/deep/x.txt", "x\n")
    answers, infos, errors, prompts = {}, {}, {}, {}
    return dired.open(tmp)
end

local tests = {}
local function test(name, fn)
    tests[#tests + 1] = { name = name, fn = fn }
end

test("lists . and .. first, directories first, names case-insensitively", function()
    local buf = setup_tree()
    eq(names(buf), { ".", "..", "sub", "zdir", ".hidden", "a.txt", "b.txt", "C.md" })
    eq(api.nvim_buf_get_name(buf), tmp)
    eq(vim.bo[buf].filetype, "dired")
    eq(api.nvim_buf_get_lines(buf, 0, 1, false)[1], "  " .. tmp .. ":")
    eq(cursor_name(buf), "sub", "cursor starts on the first real entry")
    local line = api.nvim_get_current_line()
    ok(line:match("^  d[rwx-]+%s+%d+ ") ~= nil, "ls -l style details: " .. line)
    eq(api.nvim_win_get_cursor(0)[2], buffer.state[buf].name_cols[3], "cursor on the name column")
end)

test("mark, unmark, toggle, U; marks survive a re-read; . and .. never marked", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("m")
    eq(buffer.state[buf].marks["a.txt"], "*")
    eq(cursor_name(buf), "b.txt", "m moves down")
    eq(api.nvim_buf_get_lines(buf, buffer.row_of(buf, "a.txt") - 1, buffer.row_of(buf, "a.txt"), false)[1]:sub(1, 1), "*")
    press("<C-l>")
    eq(buffer.state[buf].marks["a.txt"], "*")
    goto_name(buf, ".")
    press("m")
    press("m")
    eq(buffer.state[buf].marks["."], nil)
    eq(buffer.state[buf].marks[".."], nil)
    press("t")
    eq(buffer.state[buf].marks["a.txt"], nil)
    eq(buffer.state[buf].marks["b.txt"], "*")
    eq(buffer.state[buf].marks["."], nil)
    press("U")
    eq(next(buffer.state[buf].marks), nil)
end)

test("count and visual range marking; flag with d", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("2m")
    eq(buffer.state[buf].marks["a.txt"], "*")
    eq(buffer.state[buf].marks["b.txt"], "*")
    eq(buffer.state[buf].marks["C.md"], nil)
    press("U")
    goto_name(buf, "sub")
    press("Vjjm")
    eq(buffer.state[buf].marks["sub"], "*")
    eq(buffer.state[buf].marks["zdir"], "*")
    eq(buffer.state[buf].marks[".hidden"], "*")
    goto_name(buf, "C.md")
    press("d")
    eq(buffer.state[buf].marks["C.md"], "D")
end)

test("dired keys are nowait, so global maps like ds or ys cannot delay them", function()
    local buf = setup_tree()
    local found = 0
    for _, m in ipairs(api.nvim_buf_get_keymap(buf, "n")) do
        if m.desc and m.desc:sub(1, 6) == "dired:" then
            eq(m.nowait, 1, m.lhs)
            found = found + 1
        end
    end
    ok(found > 50, "found " .. found .. " maps")
end)

test("x deletes flagged files after yes; recursive directories ask again", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("d")
    goto_name(buf, "zdir")
    press("d")
    answers = { "yes", "y" }
    press("x")
    ok(not fs.exists(tmp .. "/a.txt"))
    ok(not fs.exists(tmp .. "/zdir"))
    ok(prompts[2]:match("Recursively delete zdir"))
    ok(not vim.tbl_contains(names(buf), "a.txt"))
end)

test("x with 'no' deletes nothing; D deletes the cursor file", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("d")
    answers = { "no" }
    press("x")
    ok(fs.exists(tmp .. "/a.txt"))
    goto_name(buf, "b.txt")
    answers = { "yes" }
    press("D")
    ok(not fs.exists(tmp .. "/b.txt"))
    ok(fs.exists(tmp .. "/a.txt"), "flagged but not executed")
end)

test("copy a file to a new name puts the cursor on it", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    answers = { "a2.txt" }
    press("C")
    eq(read(tmp .. "/a2.txt"), "alpha\nneedle here\n")
    eq(cursor_name(buf), "a2.txt")
end)

test("copy marked files into a directory, directories recursively", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("m")
    goto_name(buf, "zdir")
    press("m")
    answers = { tmp .. "/sub/", "y" }
    press("C")
    eq(read(tmp .. "/sub/a.txt"), "alpha\nneedle here\n")
    eq(read(tmp .. "/sub/zdir/deep/x.txt"), "x\n")
    ok(fs.exists(tmp .. "/a.txt"), "source kept")
    eq(buffer.state[buf].marks["a.txt"], nil, "copied files unmarked")
end)

test("copy onto an existing file asks; n keeps it, y overwrites", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    answers = { "b.txt", "n" }
    press("C")
    eq(read(tmp .. "/b.txt"), "bee\n")
    answers = { "b.txt", "y" }
    press("C")
    eq(read(tmp .. "/b.txt"), "alpha\nneedle here\n")
end)

test("copying a directory into itself is refused", function()
    local buf = setup_tree()
    goto_name(buf, "zdir")
    answers = { tmp .. "/zdir/deep/" }
    press("C")
    ok(#errors > 0 and errors[1]:match("into itself"), vim.inspect(errors))
    ok(not fs.exists(tmp .. "/zdir/deep/zdir"))
end)

test("rename into a directory follows open buffers", function()
    local buf = setup_tree()
    vim.cmd("edit " .. tmp .. "/a.txt")
    local fbuf = api.nvim_get_current_buf()
    dired.open(tmp)
    goto_name(buf, "a.txt")
    answers = { "sub/" }
    press("R")
    ok(not fs.exists(tmp .. "/a.txt"))
    ok(fs.exists(tmp .. "/sub/a.txt"))
    eq(api.nvim_buf_get_name(fbuf), tmp .. "/sub/a.txt")
end)

test("rename several marked files needs a directory target", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("2m")
    answers = { tmp .. "/C.md" }
    press("R")
    ok(errors[1]:match("Not a directory"))
    ok(fs.exists(tmp .. "/a.txt") and fs.exists(tmp .. "/b.txt"))
end)

test("rename a directory updates its dired buffer", function()
    local buf = setup_tree()
    local sub = dired.open(tmp .. "/sub")
    dired.open(tmp)
    goto_name(buf, "sub")
    answers = { "renamed" }
    press("R")
    eq(buffer.state[sub].dir, tmp .. "/renamed")
    eq(api.nvim_buf_get_name(sub), tmp .. "/renamed")
end)

test("+ creates nested directories and lands on the first new one", function()
    local buf = setup_tree()
    answers = { "new/one/two" }
    press("+")
    ok(fs.is_dir(tmp .. "/new/one/two"))
    eq(cursor_name(buf), "new")
end)

test("S and Y create absolute and relative symlinks; H a hard link", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    answers = { "sub/abs" }
    press("S")
    eq(uv.fs_readlink(tmp .. "/sub/abs"), tmp .. "/a.txt")
    goto_name(buf, "a.txt")
    answers = { "sub/rel" }
    press("Y")
    eq(uv.fs_readlink(tmp .. "/sub/rel"), "../a.txt")
    eq(read(tmp .. "/sub/rel"), "alpha\nneedle here\n")
    goto_name(buf, "b.txt")
    answers = { "b-hard" }
    press("H")
    eq(uv.fs_stat(tmp .. "/b-hard").ino, uv.fs_stat(tmp .. "/b.txt").ino)
end)

test("M changes mode, T touches with a timestamp", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    answers = { "750" }
    press("M")
    eq(bit.band(uv.fs_stat(tmp .. "/a.txt").mode, 511), 488)
    goto_name(buf, "b.txt")
    answers = { "202001021530" }
    press("T")
    eq(os.date("%Y-%m-%d %H:%M", uv.fs_stat(tmp .. "/b.txt").mtime.sec), "2020-01-02 15:30")
end)

test("s sorts by date, newest first; g. hides dotfiles", function()
    local buf = setup_tree()
    uv.fs_utime(tmp .. "/b.txt", os.time() + 100, os.time() + 100)
    press("s")
    eq(buffer.state[buf].sort, "time")
    eq(names(buf)[5], "b.txt")
    press("g.")
    ok(not vim.tbl_contains(names(buf), ".hidden"))
    ok(not vim.tbl_contains(names(buf), "."))
    ok(vim.tbl_contains(names(buf), ".."))
end)

test("( hides details and keeps the cursor on the name", function()
    local buf = setup_tree()
    goto_name(buf, "b.txt")
    press("(")
    eq(api.nvim_get_current_line(), "  b.txt")
    eq(api.nvim_win_get_cursor(0)[2], 2)
end)

test("<CR> enters a directory, ^ goes up with the cursor on it", function()
    local buf = setup_tree()
    goto_name(buf, "zdir")
    press("<CR>")
    local zbuf = api.nvim_get_current_buf()
    eq(buffer.state[zbuf].dir, tmp .. "/zdir")
    eq(cursor_name(zbuf), "deep")
    press("^")
    eq(api.nvim_get_current_buf(), buf)
    eq(cursor_name(buf), "zdir")
    goto_name(buf, "..")
    press("<CR>")
    eq(cursor_name(api.nvim_get_current_buf()), fs.basename(tmp))
end)

test(":DiredJump from a file lands on that file; :e on a directory opens dired", function()
    setup_tree()
    vim.cmd("edit " .. tmp .. "/sub/inner.txt")
    vim.cmd("DiredJump")
    local b = api.nvim_get_current_buf()
    eq(buffer.state[b].dir, tmp .. "/sub")
    eq(cursor_name(b), "inner.txt")
    vim.cmd("enew")
    vim.cmd("edit " .. vim.fn.fnameescape(tmp .. "/zdir"))
    local z = api.nvim_get_current_buf()
    ok(buffer.state[z] ~= nil, "directory buffer taken over")
    eq(api.nvim_buf_get_name(z), tmp .. "/zdir")
end)

test("regexp marking, flagging and %R rename with confirmation", function()
    local buf = setup_tree()
    answers = { [[\.txt$]] }
    press("%m")
    eq(buffer.state[buf].marks["a.txt"], "*")
    eq(buffer.state[buf].marks["b.txt"], "*")
    eq(buffer.state[buf].marks["C.md"], nil)
    answers = { [[\.txt$]], ".text", "y", "n" }
    press("%R")
    ok(fs.exists(tmp .. "/a.text"))
    ok(fs.exists(tmp .. "/b.txt"), "second rename declined")
    answers = { "^C" }
    press("%d")
    eq(buffer.state[buf].marks["C.md"], "D")
end)

test("%g marks files by content; %u upper-cases names", function()
    local buf = setup_tree()
    answers = { "needle" }
    press("%g")
    eq(buffer.state[buf].marks["a.txt"], "*")
    eq(buffer.state[buf].marks["b.txt"], nil)
    press("%u")
    ok(fs.exists(tmp .. "/A.TXT") and read(tmp .. "/A.TXT") == "alpha\nneedle here\n")
end)

test("shell command rules for * and ?", function()
    eq(ops.shell_commands("wc -l *", { "a b", "c" }), { "wc -l 'a b' 'c'" })
    eq(ops.shell_commands("cp ? backup/", { "a" }), { "cp 'a' backup/" })
    eq(ops.shell_commands("cp ? ?.bak", { "a" }), { "cp 'a' ?.bak" }, "only a lone ? is replaced")
    eq(ops.shell_commands("gzip", { "a", "b" }), { "gzip 'a'", "gzip 'b'" })
    eq(ops.shell_commands("echo *.txt", { "a" }), { "echo *.txt 'a'" })
end)

test("! runs in the directory and refreshes", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("m")
    goto_name(buf, "b.txt")
    press("m")
    answers = { "cat * > joined" }
    press("!")
    eq(read(tmp .. "/joined"), "alpha\nneedle here\nbee\n")
    ok(vim.tbl_contains(names(buf), "joined"))
end)

test("wdired renames, swaps names and moves into new directories", function()
    local buf = setup_tree()
    goto_name(buf, "a.txt")
    press("<C-x><C-q>")
    eq(vim.bo[buf].buftype, "acwrite")
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, { "sub", "zdir", ".hidden", "a.txt", "b.txt", "C.md" })
    vim.cmd([[silent %s/^a\.txt$/TMPNAME/e]])
    vim.cmd([[silent %s/^b\.txt$/a.txt/e]])
    vim.cmd([[silent %s/^TMPNAME$/b.txt/e]])
    vim.cmd([[silent %s/^C\.md$/docs\/C.md/e]])
    vim.cmd("write")
    eq(read(tmp .. "/a.txt"), "bee\n")
    eq(read(tmp .. "/b.txt"), "alpha\nneedle here\n")
    eq(read(tmp .. "/docs/C.md"), "# c\n")
    eq(vim.bo[buf].buftype, "nofile")
    ok(buffer.state[buf].wdired == nil)
    eq(#vim.fn.glob(tmp .. "/.dired-tmp-*", true, true), 0, "no temp files left")
end)

test("wdired refuses deleted lines and existing targets, and abort restores", function()
    local buf = setup_tree()
    press("<C-x><C-q>")
    vim.cmd("2delete")
    vim.cmd("write")
    ok(errors[#errors]:match("WDired only renames"), vim.inspect(errors))
    ok(buffer.state[buf].wdired ~= nil, "still editing")
    vim.cmd("silent undo")
    vim.cmd([[silent %s/^a\.txt$/b.txt/e]])
    vim.cmd("write")
    ok(errors[#errors]:match("already exists"), vim.inspect(errors))
    ok(fs.exists(tmp .. "/a.txt"))
    press("<C-c><C-k>")
    ok(buffer.state[buf].wdired == nil)
    eq(names(buf)[1], ".")
end)

test("A without Telescope fills the quickfix list from ripgrep", function()
    local buf = setup_tree()
    package.loaded["telescope.builtin"] = nil
    local saved = package.preload["telescope.builtin"]
    package.preload["telescope.builtin"] = function()
        error("no telescope")
    end
    goto_name(buf, ".")
    answers = { "needle" }
    press("A")
    package.preload["telescope.builtin"] = saved
    local qf = vim.fn.getqflist()
    eq(#qf, 2)
    vim.cmd("cclose")
    ok(api.nvim_get_current_buf() == buf)
end)

test("Q replaces in marked files through :cdo", function()
    local buf = setup_tree()
    goto_name(buf, "sub")
    press("m")
    goto_name(buf, "a.txt")
    press("m")
    answers = { "needle", "pin" }
    require("dired.search").query_replace(buf, { flags = "ge" })
    vim.cmd("silent wall")
    eq(read(tmp .. "/a.txt"), "alpha\npin here\n")
    eq(read(tmp .. "/sub/inner.txt"), "inner pin\n")
end)

test("a directory reached through a symlink reuses one buffer", function()
    setup_tree()
    local link = fs.absolute(vim.fn.tempname())
    assert(uv.fs_symlink(tmp, link))
    local a = dired.open(link)
    local b = dired.open(tmp)
    eq(a, b)
    vim.cmd("enew")
    vim.cmd("edit " .. vim.fn.fnameescape(link))
    vim.wait(50)
    eq(api.nvim_get_current_buf(), a)
end)

test("deleting a directory wipes its hidden dired buffer", function()
    local buf = setup_tree()
    local zbuf = dired.open(tmp .. "/zdir")
    dired.open(tmp)
    goto_name(buf, "zdir")
    answers = { "yes", "y" }
    press("D")
    ok(not api.nvim_buf_is_valid(zbuf))
end)

test("other keys: ?, < >, */, w, W, <BS>, *N, o, q, =, &", function()
    local buf = setup_tree()
    press("?")
    ok(api.nvim_win_get_config(0).relative ~= "", "help is a float")
    press("q")
    eq(api.nvim_get_current_buf(), buf)
    goto_name(buf, "b.txt")
    press("<")
    eq(cursor_name(buf), "zdir")
    press("<")
    eq(cursor_name(buf), "sub")
    press(">")
    eq(cursor_name(buf), "zdir")
    press("*/")
    eq(buffer.state[buf].marks["sub"], "*")
    eq(buffer.state[buf].marks["zdir"], "*")
    eq(buffer.state[buf].marks["a.txt"], nil)
    press("w")
    eq(vim.fn.getreg('"'), "sub zdir")
    press("W")
    eq(vim.fn.getreg('"'), tmp .. "/sub " .. tmp .. "/zdir")
    goto_name(buf, ".hidden")
    press("<BS>")
    eq(buffer.state[buf].marks["zdir"], nil)
    eq(cursor_name(buf), "zdir")
    press("*N")
    eq(infos[#infos], "1 marked, 0 flagged")
    press("U")
    goto_name(buf, "a.txt")
    press("o")
    eq(#api.nvim_tabpage_list_wins(0), 2)
    eq(api.nvim_buf_get_name(0), tmp .. "/a.txt")
    vim.cmd("wincmd p")
    eq(api.nvim_get_current_buf(), buf)
    press("q")
    ok(api.nvim_get_current_buf() ~= buf, "q leaves the dired buffer")
    dired.open(tmp)
    goto_name(buf, "a.txt")
    answers = { "b.txt" }
    press("=")
    ok(vim.wo.diff, "diff window open")
    vim.cmd("tabclose")
    dired.open(tmp)
    goto_name(buf, "a.txt")
    answers = { "cp ? copied-async" }
    press("&")
    vim.wait(3000, function()
        return fs.exists(tmp .. "/copied-async")
    end)
    ok(fs.exists(tmp .. "/copied-async"))
end)

test("fs.relpath and fs.absolute", function()
    eq(fs.relpath("/a/b", "/a/c/d"), "../c/d")
    eq(fs.relpath("/a", "/a/b"), "b")
    eq(fs.absolute("x/../y", "/base"), "/base/y")
    eq(fs.absolute("~/f"), vim.env.HOME .. "/f")
    eq(fs.absolute("/a/b/"), "/a/b")
    eq(fs.absolute("$HOME/x", "/base"), "/base/$HOME/x")
end)

local failed = 0
for _, t in ipairs(tests) do
    local okk, err = xpcall(t.fn, debug.traceback)
    if okk then
        io.stdout:write("ok   " .. t.name .. "\n")
    else
        failed = failed + 1
        io.stdout:write("FAIL " .. t.name .. "\n" .. err .. "\n")
    end
end
io.stdout:write(string.format("\n%d tests, %d failed\n", #tests, failed))
vim.cmd((failed == 0 and "qa!" or "cq!"))
