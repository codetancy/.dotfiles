-- Search from a dired buffer: grep and query-replace in the marked files, and
-- Telescope pickers scoped to the listed directory.

local api = vim.api
local buffer = require("dired.buffer")
local fs = require("dired.fs")
local ui = require("dired.ui")

local M = {}

local function telescope()
    local ok, builtin = pcall(require, "telescope.builtin")
    return ok and builtin or nil
end

local function paths_of(buf)
    local entries = buffer.targets(buf)
    local paths = {}
    for _, e in ipairs(entries) do
        paths[#paths + 1] = e.path
    end
    if #paths == 0 then
        paths = { buffer.state[buf].dir }
    end
    return paths
end

local function describe(paths)
    return #paths == 1 and fs.basename(paths[1]) or (#paths .. " files")
end

-- A (dired-do-find-regexp): live grep in the marked files and directories.
function M.grep(buf)
    local paths = paths_of(buf)
    local dir = buffer.state[buf].dir
    local builtin = telescope()
    if builtin then
        builtin.live_grep({ cwd = dir, search_dirs = paths, prompt_title = "Grep in " .. describe(paths) })
        return
    end
    local pat = ui.input("Grep in " .. describe(paths) .. " (ripgrep regexp): ")
    if not pat or pat == "" then
        return
    end
    local cmd = { "rg", "--vimgrep", "--no-messages", "-e", pat, "--" }
    vim.list_extend(cmd, paths)
    local res = vim.system(cmd, { cwd = dir, text = true }):wait()
    if res.code > 1 then
        ui.error(vim.trim(res.stderr or "rg failed"))
        return
    end
    vim.fn.setqflist({}, " ", {
        title = "rg " .. pat,
        lines = vim.split(res.stdout or "", "\n", { trimempty = true }),
        efm = "%f:%l:%c:%m",
    })
    if #vim.fn.getqflist() == 0 then
        ui.info("No matches for " .. pat)
        return
    end
    vim.cmd("copen")
end

-- Files under `paths`, recursing into directories and honouring .gitignore when rg exists.
function M.expand(paths, dir)
    local files, dirs = {}, {}
    for _, p in ipairs(paths) do
        if fs.is_dir(p) then
            dirs[#dirs + 1] = p
        else
            files[#files + 1] = p
        end
    end
    if #dirs > 0 then
        local ok, res = pcall(function()
            local cmd = { "rg", "--files", "--hidden", "-g", "!.git", "--" }
            vim.list_extend(cmd, dirs)
            return vim.system(cmd, { cwd = dir, text = true }):wait()
        end)
        if ok and res.code <= 1 then
            for _, f in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
                files[#files + 1] = fs.absolute(f, dir)
            end
        else
            for _, d in ipairs(dirs) do
                for name, t in vim.fs.dir(d, { depth = 50 }) do
                    if t == "file" then
                        files[#files + 1] = fs.join(d, name)
                    end
                end
            end
        end
    end
    return files
end

-- Q (dired-do-find-regexp-and-replace): every matching line goes to the
-- quickfix list, then :cdo runs :s with the c flag so each match is confirmed.
-- Changed buffers are left unsaved for review (:wa writes them).
function M.query_replace(buf, opts)
    opts = opts or {}
    local paths = paths_of(buf)
    local dir = buffer.state[buf].dir
    local pat = ui.input("Query replace in " .. describe(paths) .. " (Vim regexp): ")
    if not pat or pat == "" then
        return
    end
    if not pcall(vim.regex, pat) then
        ui.error("Invalid regexp: " .. pat)
        return
    end
    local rep = ui.input("Replace '" .. pat .. "' with: ")
    if rep == nil then
        return
    end
    local files = M.expand(paths, dir)
    if #files == 0 then
        ui.info("No files to search")
        return
    end
    local re = vim.regex(pat)
    local items = {}
    for _, f in ipairs(files) do
        local okr, lines = pcall(vim.fn.readfile, f)
        if okr then
            for lnum, line in ipairs(lines) do
                if line:find("%z") then
                    break
                end
                local s = re:match_str(line)
                if s then
                    items[#items + 1] = { filename = f, lnum = lnum, col = s + 1, text = line }
                end
            end
        end
    end
    if #items == 0 then
        ui.info("No matches for " .. pat)
        return
    end
    vim.fn.setqflist({}, " ", { title = "Query replace " .. pat, items = items })
    local flags = opts.flags or "gce"
    vim.cmd("cdo s/" .. vim.fn.escape(pat, "/") .. "/" .. vim.fn.escape(rep, "/") .. "/" .. flags)
    local modified = 0
    for _, b in ipairs(api.nvim_list_bufs()) do
        if vim.bo[b].modified then
            modified = modified + 1
        end
    end
    ui.info(string.format("Replaced in %d buffer%s; review and :wa to save", modified, modified == 1 and "" or "s"))
end

function M.find_files(buf)
    local builtin = telescope()
    if not builtin then
        ui.error("Telescope is not installed")
        return
    end
    local s = buffer.state[buf]
    builtin.find_files({ cwd = s.dir, hidden = s.hidden, prompt_title = "Find files in " .. s.dir })
end

function M.live_grep(buf)
    local builtin = telescope()
    if not builtin then
        ui.error("Telescope is not installed")
        return
    end
    local s = buffer.state[buf]
    builtin.live_grep({ cwd = s.dir, prompt_title = "Grep in " .. s.dir })
end

return M
