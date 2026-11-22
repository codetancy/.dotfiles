-- Prompts. Every prompt returns nil when cancelled. Tests replace these functions.

local M = {}

local CANCEL = "\1dired-cancel\1"

function M.input(prompt, default, completion)
    local ok, answer = pcall(vim.fn.input, {
        prompt = prompt,
        default = default or "",
        completion = completion,
        cancelreturn = CANCEL,
    })
    vim.cmd("redraw")
    if not ok or answer == CANCEL then
        return nil
    end
    return answer
end

-- Answers that must be typed in full, like Emacs yes-or-no-p.
function M.yes_or_no(prompt)
    while true do
        local answer = M.input(prompt .. "(yes or no) ")
        if answer == nil or answer == "no" then
            return false
        end
        if answer == "yes" then
            return true
        end
    end
end

-- Single-key answer from `choices`, e.g. { "y", "n", "!", "q" }.
function M.choice(prompt, choices)
    local valid = {}
    for _, c in ipairs(choices) do
        valid[c] = true
    end
    while true do
        vim.api.nvim_echo({ { prompt, "Question" } }, false, {})
        local ok, key = pcall(vim.fn.getcharstr)
        vim.cmd("redraw")
        if not ok or key == "\27" or key == "\3" then
            return nil
        end
        if valid[key] then
            return key
        end
    end
end

function M.y_or_n(prompt)
    return M.choice(prompt .. "(y or n) ", { "y", "n" }) == "y"
end

function M.info(msg)
    vim.notify(msg, vim.log.levels.INFO, { title = "dired" })
end

function M.error(msg)
    vim.notify(msg, vim.log.levels.ERROR, { title = "dired" })
end

return M
