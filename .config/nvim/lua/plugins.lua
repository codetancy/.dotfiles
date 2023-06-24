-- Bootstrap Packer
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath("data")
      .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({
      "git",
      "clone",
      "--depth",
      "1",
      "https://github.com/wbthomason/packer.nvim",
      install_path,
    })
    pcall(vim.cmd, 'packadd packer.nvim')
    pcall(vim.cmd, 'let &runtimepath = &runtimepath')
    return true
  end
  return false
end

PACKER_BOOTSTRAP = ensure_packer()

-- Run PackerCompile whenever we edit this file with `nvim`.
pcall(vim.cmd,
  'augroup packer_user_config autocmd! autocmd BufWritePost plugins.lua source <afile> | PackerCompile augroup end')

return require("packer").startup(function(use)
  -- Packer can manage itself
  use({ "wbthomason/packer.nvim" })

  -- colorscheme
  use({ 'morhetz/gruvbox' })
  use({ 'luisiacc/gruvbox-baby' })

  -- comments
  use({ "tpope/vim-commentary" })

  -- lualine
  use({
    "nvim-lualine/lualine.nvim",
    requires = { "nvim-tree/nvim-web-devicons", opt = true }
  })

  -- telescope
  use({
    'nvim-telescope/telescope.nvim',
    tag = '0.1.1',
    requires = { { 'nvim-lua/plenary.nvim' } }
  })

  use({
    'neovim/nvim-lspconfig',
    requires = {
      -- LSP support
      {
        'williamboman/mason.nvim',
        run = function() pcall(vim.cmd, 'MasonUpdate') end
      },
      { 'williamboman/mason-lspconfig.nvim' },

      -- Autocompletion
      { 'hrsh7th/nvim-cmp' },
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'hrsh7th/cmp-buffer' },
      { 'hrsh7th/cmp-path' },
      { 'L3MON4D3/LuaSnip' },
      { 'saadparwaiz1/cmp_luasnip' }
    }
  })

  use({ 'simrat39/rust-tools.nvim' })

  use({ 'folke/which-key.nvim' })

  -- treesitter
  use {
    'nvim-treesitter/nvim-treesitter'
  }

  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
