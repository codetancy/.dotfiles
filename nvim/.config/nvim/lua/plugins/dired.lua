return {
    dir = vim.fn.stdpath("config") .. "/dired.nvim",
    name = "dired.nvim",
    lazy = false,
    init = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
    end,
    config = function()
        require("dired").setup({})
    end,
}
