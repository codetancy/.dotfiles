-- Default keys, following Emacs dired where that does not break core Vim
-- motions (j, k, n, p, g, G, / and v keep their Vim meaning).

local M = {}

local N, NX = { "n" }, { "n", "x" }

M.defaults = {
    { "<CR>", "nav.open", "Open file or directory" },
    { "e", "nav.open", "Open file or directory" },
    { "f", "nav.open", "Open file or directory" },
    { "o", "nav.open_other", "Open in the other window" },
    { "^", "nav.up", "Parent directory" },
    { "-", "nav.up", "Parent directory" },
    { "q", "nav.quit", "Quit dired buffer" },
    { "<C-l>", "nav.refresh", "Re-read directory (dired g)" },
    { "s", "nav.toggle_sort", "Sort by name or date" },
    { "(", "nav.toggle_details", "Hide or show details" },
    { "g.", "nav.toggle_hidden", "Hide or show dotfiles" },
    { "<", "nav.prev_dir", "Previous directory line" },
    { ">", "nav.next_dir", "Next directory line" },
    { "?", "nav.help", "Show these keys" },

    { "m", "marks.mark", "Mark", NX },
    { "u", "marks.unmark", "Unmark", NX },
    { "d", "marks.flag", "Flag for deletion", NX },
    { "t", "marks.toggle", "Toggle marks" },
    { "U", "marks.unmark_all", "Unmark all" },
    { "<BS>", "marks.unmark_backward", "Unmark previous line" },
    { "*/", "marks.mark_directories", "Mark directories" },
    { "**", "marks.mark_executables", "Mark executables" },
    { "*@", "marks.mark_symlinks", "Mark symlinks" },
    { "*.", "marks.mark_extension", "Mark by extension" },
    { "*N", "marks.count", "Count marked files" },
    { "%m", "marks.mark_regexp", "Mark names matching a Vim regexp" },
    { "%d", "marks.flag_regexp", "Flag names matching a Vim regexp" },
    { "%g", "marks.mark_containing", "Mark files whose contents match (ripgrep)" },
    { "~", "marks.flag_backups", "Flag backup files (~)" },

    { "x", "ops.delete_flagged", "Delete flagged files" },
    { "D", "ops.delete", "Delete marked files" },
    { "C", "ops.copy", "Copy" },
    { "R", "ops.rename", "Rename or move" },
    { "S", "ops.symlink", "Absolute symlink" },
    { "Y", "ops.relsymlink", "Relative symlink" },
    { "H", "ops.hardlink", "Hard link" },
    { "+", "ops.mkdir", "Create directory" },
    { "M", "ops.chmod", "Change mode" },
    { "T", "ops.touch", "Change timestamp" },
    { "!", "ops.shell", "Shell command" },
    { "&", "ops.async_shell", "Shell command in the background" },
    { "%R", "ops.rename_regexp", "Rename by Vim regexp" },
    { "%u", "ops.upcase", "Rename to upper case" },
    { "%l", "ops.downcase", "Rename to lower case" },
    { "=", "ops.diff", "Diff with another file" },
    { "E", "ops.open_external", "Open with the system app" },
    { "F", "ops.find_marked", "Edit marked files" },
    { "w", "ops.copy_names", "Copy file names" },
    { "W", "ops.copy_paths", "Copy absolute paths" },
    { "y", "ops.file_type", "Show file type" },

    { "A", "search.grep", "Grep in marked files" },
    { "Q", "search.query_replace", "Query replace in marked files" },
    { "<leader>sf", "search.find_files", "Find files under this directory" },
    { "<leader>sg", "search.live_grep", "Grep under this directory" },

    { "<C-x><C-q>", "wdired.enter", "Edit names in the buffer (wdired)" },
}

local function resolve(action)
    local mod, fn = action:match("^(%w+)%.([%w_]+)$")
    return require("dired." .. mod)[fn]
end

function M.list()
    local overrides = require("dired.config").options.keymaps or {}
    local out = {}
    for _, m in ipairs(M.defaults) do
        if overrides[m[1]] ~= false then
            out[#out + 1] = { lhs = m[1], action = m[2], desc = m[3], modes = m[4] or N }
        end
    end
    for lhs, action in pairs(overrides) do
        if type(action) == "string" then
            local found = false
            for _, m in ipairs(out) do
                if m.lhs == lhs then
                    m.action = action
                    found = true
                end
            end
            if not found then
                out[#out + 1] = { lhs = lhs, action = action, desc = action, modes = N }
            end
        end
    end
    return out
end

function M.apply(buf)
    for _, m in ipairs(M.list()) do
        local fn = resolve(m.action)
        vim.keymap.set(m.modes, m.lhs, function()
            fn(buf)
        end, { buffer = buf, silent = true, nowait = true, desc = "dired: " .. m.desc })
    end
end

function M.clear(buf)
    for _, m in ipairs(M.list()) do
        for _, mode in ipairs(m.modes) do
            pcall(vim.keymap.del, mode, m.lhs, { buffer = buf })
        end
    end
end

return M
