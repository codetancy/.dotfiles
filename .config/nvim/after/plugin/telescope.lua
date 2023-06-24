local ok_status, telescope = pcall(require, "telescope")
if not ok_status then
  return
end

local actions = require("telescope.actions")

-- telescope.setup({
--   defaults = {
--     mappings = {
--       i = {
--         ["<esc>"] = actions.close,
--         -- ["<C-j>"] = actions.move_selection_next,
--         -- ["<C-k>"] = actions.move_selection_previous,
--         ["<tab>"] = actions.toggle_selection + actions.move_selection_next,
--         ["<s-tab>"] = actions.toggle_selection + actions.move_selection_previous,
--         -- ["<cr>"] = custom_actions.multi_selection_open,
--         -- ["<c-v>"] = custom_actions.multi_selection_open_vsplit,
--         -- ["<c-s>"] = custom_actions.multi_selection_open_split,
--         -- ["<c-t>"] = custom_actions.multi_selection_open_tab,
--       },
--       n = {
--         ["<esc>"] = actions.close,
--         ["<tab>"] = actions.toggle_selection + actions.move_selection_next,
--         ["<s-tab>"] = actions.toggle_selection + actions.move_selection_previous,
--         -- ["<cr>"] = custom_actions.multi_selection_open,
--         -- ["<c-v>"] = custom_actions.multi_selection_open_vsplit,
--         -- ["<c-s>"] = custom_actions.multi_selection_open_split,
--         -- ["<c-t>"] = custom_actions.multi_selection_open_tab,
--       },
--     },
--   },
-- })

local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>so", builtin.buffers,
  { noremap = true, silent = true, desc = 'Search open buffers' })
vim.keymap.set("n", "<leader>sb", builtin.current_buffer_fuzzy_find,
  { noremap = true, silent = true, desc = 'Search current buffer' })
vim.keymap.set("n", "<leader>sf", builtin.find_files,
  { noremap = true, silent = true, desc = 'Search files' })
vim.keymap.set("n", "<leader>sk", builtin.keymaps,
  { noremap = true, silent = true, desc = 'Search keymaps' })
vim.keymap.set("n", "<leader>sh", builtin.help_tags,
  { noremap = true, silent = true, desc = 'Search help' })
