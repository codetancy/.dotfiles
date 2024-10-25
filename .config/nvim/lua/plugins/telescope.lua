return {
    "nvim-telescope/telescope.nvim",
    event = "VeryLazy",
    tag = "0.1.8",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    keys = {
        {
            "<leader>sb",
            function()
                require("telescope.builtin").current_buffer_fuzzy_find()
            end,
        },
        {
            "<leader>sf",
            function()
                require("telescope.builtin").find_files()
            end,
        },
        {
            "<leader>sg",
            function()
                require("telescope.builtin").live_grep()
            end,
        }
    },
    config = function()
        local telescope = require("telescope")
        telescope.setup({})
    end,
}
