-- Filesystem layer. Every function returns true (or a value) on success and
-- nil plus an error message on failure; none of them raise.

local uv = vim.uv
local bit = require("bit")

local M = {}

function M.join(dir, name)
    if dir == "/" then
        return "/" .. name
    end
    return dir .. "/" .. name
end

function M.absolute(path, base)
    if path == "~" or path:sub(1, 2) == "~/" then
        path = vim.env.HOME .. path:sub(2)
    end
    if path:sub(1, 1) ~= "/" then
        path = M.join(base or uv.cwd(), path)
    end
    path = vim.fs.normalize(path, { expand_env = false })
    if #path > 1 then
        path = (path:gsub("/+$", ""))
    end
    return path
end

function M.parent(path)
    if path == "/" then
        return "/"
    end
    return vim.fs.dirname(path)
end

function M.basename(path)
    return vim.fs.basename(path)
end

function M.exists(path)
    return uv.fs_lstat(path) ~= nil
end

function M.is_dir(path)
    local st = uv.fs_stat(path)
    return st ~= nil and st.type == "directory"
end

function M.is_real_dir(path)
    local st = uv.fs_lstat(path)
    return st ~= nil and st.type == "directory"
end

function M.is_empty_dir(path)
    local handle = uv.fs_scandir(path)
    return handle ~= nil and uv.fs_scandir_next(handle) == nil
end

-- Symlink-free absolute path. For a path that no longer exists, resolves its
-- parent instead, so a just-renamed or just-deleted path still compares equal
-- to buffer names, which Neovim stores resolved.
function M.real(path)
    local r = uv.fs_realpath(path)
    if r then
        return r
    end
    local parent = M.parent(path)
    if parent ~= path then
        local rp = uv.fs_realpath(parent)
        if rp then
            return M.join(rp, M.basename(path))
        end
    end
    return path
end

function M.same_file(a, b)
    local sa, sb = uv.fs_lstat(a), uv.fs_lstat(b)
    return sa ~= nil and sb ~= nil and sa.ino == sb.ino and sa.dev == sb.dev
end

function M.is_ancestor(dir, path)
    if dir == "/" then
        return true
    end
    return path == dir or path:sub(1, #dir + 1) == dir .. "/"
end

local function entry(name, path)
    local st = uv.fs_lstat(path)
    if not st then
        return nil
    end
    local e = {
        name = name,
        path = path,
        type = st.type,
        mode = st.mode,
        nlink = st.nlink,
        uid = st.uid,
        gid = st.gid,
        size = st.size,
        mtime = st.mtime.sec,
        blocks = st.blocks or 0,
    }
    if st.type == "link" then
        e.target = uv.fs_readlink(path) or "?"
        local target = uv.fs_stat(path)
        e.target_type = target and target.type or nil
    end
    return e
end

function M.list(dir)
    local handle, err = uv.fs_scandir(dir)
    if not handle then
        return nil, err
    end
    local entries = {}
    for _, special in ipairs({ { ".", dir }, { "..", M.parent(dir) } }) do
        local e = entry(special[1], special[2])
        if e then
            entries[#entries + 1] = e
        end
    end
    while true do
        local name = uv.fs_scandir_next(handle)
        if not name then
            break
        end
        local e = entry(name, M.join(dir, name))
        if e then
            entries[#entries + 1] = e
        end
    end
    return entries
end

function M.entry(path)
    return entry(M.basename(path), path)
end

local TYPE_CHAR = { directory = "d", link = "l", char = "c", block = "b", fifo = "p", socket = "s" }

function M.mode_string(e)
    local m = e.mode
    local function has(mask)
        return bit.band(m, mask) ~= 0
    end
    local function triad(r, w, x, special, char)
        local xs
        if special then
            xs = has(x) and char or char:upper()
        else
            xs = has(x) and "x" or "-"
        end
        return (has(r) and "r" or "-") .. (has(w) and "w" or "-") .. xs
    end
    return (TYPE_CHAR[e.type] or "-")
        .. triad(256, 128, 64, has(2048), "s")
        .. triad(32, 16, 8, has(1024), "s")
        .. triad(4, 2, 1, has(512), "t")
end

function M.is_executable(e)
    return e.type == "file" and bit.band(e.mode, 73) ~= 0
end

function M.is_directory_like(e)
    return e.type == "directory" or (e.type == "link" and e.target_type == "directory")
end

local function preserve(st, dst)
    uv.fs_chmod(dst, bit.band(st.mode, 4095))
    uv.fs_utime(dst, st.atime.sec, st.mtime.sec)
end

-- Copies files, directories (recursively) and symlinks (as symlinks).
-- An existing destination file is overwritten; an existing directory is not merged.
function M.copy(src, dst)
    local st, err = uv.fs_lstat(src)
    if not st then
        return nil, err
    end
    if st.type == "link" then
        local target, e1 = uv.fs_readlink(src)
        if not target then
            return nil, e1
        end
        local ok, e2 = uv.fs_symlink(target, dst)
        if not ok then
            return nil, e2
        end
        return true
    end
    if st.type == "directory" then
        local ok, e1 = uv.fs_mkdir(dst, 448)
        if not ok then
            return nil, e1
        end
        local handle, e2 = uv.fs_scandir(src)
        if not handle then
            return nil, e2
        end
        while true do
            local name = uv.fs_scandir_next(handle)
            if not name then
                break
            end
            local done, e3 = M.copy(M.join(src, name), M.join(dst, name))
            if not done then
                return nil, e3
            end
        end
        preserve(st, dst)
        return true
    end
    local ok, e1 = uv.fs_copyfile(src, dst)
    if not ok then
        return nil, e1
    end
    preserve(st, dst)
    return true
end

-- Deletes a file, symlink or directory tree. Symlinks are removed, never followed.
function M.delete(path)
    local st, err = uv.fs_lstat(path)
    if not st then
        return nil, err
    end
    if st.type == "directory" then
        local handle, e1 = uv.fs_scandir(path)
        if not handle then
            return nil, e1
        end
        while true do
            local name = uv.fs_scandir_next(handle)
            if not name then
                break
            end
            local ok, e2 = M.delete(M.join(path, name))
            if not ok then
                return nil, e2
            end
        end
        local ok, e3 = uv.fs_rmdir(path)
        if not ok then
            return nil, e3
        end
        return true
    end
    local ok, e4 = uv.fs_unlink(path)
    if not ok then
        return nil, e4
    end
    return true
end

-- Renames, falling back to copy and delete across filesystems.
function M.rename(src, dst)
    local ok, err, code = uv.fs_rename(src, dst)
    if ok then
        return true
    end
    if code == "EXDEV" then
        local copied, e1 = M.copy(src, dst)
        if not copied then
            return nil, e1
        end
        return M.delete(src)
    end
    return nil, err
end

function M.mkdir_p(path)
    local ok, err = pcall(vim.fn.mkdir, path, "p")
    if not ok then
        return nil, err
    end
    if not M.is_dir(path) then
        return nil, "cannot create directory " .. path
    end
    return true
end

function M.symlink(target, link)
    local ok, err = uv.fs_symlink(target, link)
    if not ok then
        return nil, err
    end
    return true
end

function M.hardlink(src, dst)
    local ok, err = uv.fs_link(src, dst)
    if not ok then
        return nil, err
    end
    return true
end

function M.relpath(from_dir, to)
    local a = vim.split(from_dir, "/", { trimempty = true })
    local b = vim.split(to, "/", { trimempty = true })
    local i = 1
    while i <= #a and i <= #b and a[i] == b[i] do
        i = i + 1
    end
    local parts = {}
    for _ = i, #a do
        parts[#parts + 1] = ".."
    end
    for j = i, #b do
        parts[#parts + 1] = b[j]
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
end

return M
