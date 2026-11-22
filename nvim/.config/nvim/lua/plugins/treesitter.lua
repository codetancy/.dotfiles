return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter").install({
            "bash",
            "c",
            "cpp",
            "json",
            "lua",
            "markdown",
            "markdown_inline",
            "python",
            "query",
            "rust",
            "toml",
            "vim",
            "vimdoc",
        })
        vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
                pcall(vim.treesitter.start, args.buf)
            end,
        })
    end,
}
