-- nvim-treesitter has two incompatible branches:
--   `main`   -- the rewrite; requires Neovim 0.12+ (it calls vim.list.unique)
--   `master` -- frozen, kept for backward compatibility with Neovim 0.11
-- lazy.nvim defaults to `master`, so whichever we want must be pinned explicitly.
-- Run `:Lazy sync` after crossing the 0.12 boundary so the checkout follows.

return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter.configs").setup({
            ensured_installed = {
                "c",
                "lua",
                "vim",
                "vimdoc",
                "markdown",
                "python",
                "toml",
                "json",
                "rust",
            }
        })
    end,
}
