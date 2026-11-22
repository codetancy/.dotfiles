-- Turns a directory state into buffer lines and highlight ranges, in the
-- layout of `ls -al`: mark, permissions, links, owner, group, size, date, name.

local fs = require("dired.fs")

local M = {}

local SIX_MONTHS = 15778476
local owners = {}

local function owner_group(e)
    local key = e.uid .. ":" .. e.gid
    local hit = owners[key]
    if hit then
        return hit[1], hit[2]
    end
    local cmd = vim.fn.has("mac") == 1 and { "stat", "-f", "%Su %Sg", e.path } or { "stat", "-c", "%U %G", e.path }
    local owner, group = tostring(e.uid), tostring(e.gid)
    local ok, res = pcall(function()
        return vim.system(cmd, { text = true }):wait()
    end)
    if ok and res.code == 0 then
        local o, g = res.stdout:match("^(%S+)%s+(%S+)")
        if o then
            owner, group = o, g
        end
    end
    owners[key] = { owner, group }
    return owner, group
end

function M.human(n)
    if n < 1024 then
        return tostring(n)
    end
    local units = { "K", "M", "G", "T", "P" }
    local v, i = n, 0
    repeat
        v = v / 1024
        i = i + 1
    until v < 1024 or i == #units
    local tenths = math.ceil(v * 10) / 10
    if tenths < 10 then
        return string.format("%.1f%s", tenths, units[i])
    end
    return string.format("%d%s", math.ceil(v), units[i])
end

local function date(mtime, now)
    if math.abs(now - mtime) < SIX_MONTHS then
        return os.date("%b %e %H:%M", mtime)
    end
    return os.date("%b %e  %Y", mtime)
end

function M.display_name(name)
    return (name:gsub("%c", function(c)
        if c == "\n" then
            return "\\n"
        elseif c == "\t" then
            return "\\t"
        end
        return string.format("\\%03o", c:byte())
    end))
end

local function lpad(s, w)
    return string.rep(" ", w - vim.fn.strdisplaywidth(s)) .. s
end

local function rpad(s, w)
    return s .. string.rep(" ", w - vim.fn.strdisplaywidth(s))
end

local function name_group(e)
    if fs.is_directory_like(e) then
        return "DiredDirectory"
    elseif e.type == "link" then
        return e.target_type and "DiredSymlink" or "DiredBrokenLink"
    elseif fs.is_executable(e) then
        return "DiredExecutable"
    end
    return nil
end

-- Returns lines, highlights ({ row, start_col, end_col, group }) and the byte
-- column where each entry's name starts.
function M.build(state)
    local lines, hls, name_cols = {}, {}, {}
    local function hl(row, s, e, group)
        if group and e > s then
            hls[#hls + 1] = { row, s, e, group }
        end
    end

    lines[1] = "  " .. state.dir .. ":"
    hl(0, 2, #lines[1] - 1, "DiredHeader")

    local used = 0
    for _, e in ipairs(state.entries) do
        if e.name ~= "." and e.name ~= ".." then
            used = used + e.blocks * 512
        end
    end
    local info = "  total used in directory " .. M.human(used)
    local statfs = vim.uv.fs_statfs(state.dir)
    if statfs then
        info = info .. " available " .. M.human(statfs.bavail * statfs.bsize)
    end
    if state.sort == "time" then
        info = info .. ", sorted by date"
    end
    if not state.hidden then
        info = info .. ", hidden files omitted"
    end
    lines[2] = info
    hl(1, 0, #info, "DiredDetails")

    local cols = {}
    local w = { nlink = 0, owner = 0, group = 0, size = 0 }
    if state.details then
        local now = os.time()
        for i, e in ipairs(state.entries) do
            local owner, group = owner_group(e)
            local c = {
                perms = fs.mode_string(e),
                nlink = tostring(e.nlink),
                owner = owner,
                group = group,
                size = M.human(e.size),
                date = date(e.mtime, now),
            }
            cols[i] = c
            for k in pairs(w) do
                w[k] = math.max(w[k], vim.fn.strdisplaywidth(c[k]))
            end
        end
    end

    for i, e in ipairs(state.entries) do
        local row = #lines
        local mark = state.marks[e.name] or " "
        local prefix = mark .. " "
        if state.details then
            local c = cols[i]
            prefix = prefix
                .. c.perms
                .. " "
                .. lpad(c.nlink, w.nlink)
                .. " "
                .. rpad(c.owner, w.owner)
                .. "  "
                .. rpad(c.group, w.group)
                .. "  "
                .. lpad(c.size, w.size)
                .. " "
                .. c.date
                .. " "
        end
        local name = M.display_name(e.name)
        local line = prefix .. name
        if e.type == "link" then
            line = line .. " -> " .. M.display_name(e.target)
        end
        lines[#lines + 1] = line
        name_cols[i] = #prefix

        if state.details then
            hl(row, 2, #prefix - 1, "DiredDetails")
        end
        local group = name_group(e)
        if mark == "*" then
            hl(row, 0, 1, "DiredMarked")
            group = "DiredMarked"
        elseif mark == "D" then
            hl(row, 0, 1, "DiredFlagged")
            group = "DiredFlagged"
        end
        hl(row, #prefix, #prefix + #name, group)
        if e.type == "link" then
            hl(row, #prefix + #name, #line, "DiredSymlinkTarget")
        end
    end
    return lines, hls, name_cols
end

return M
