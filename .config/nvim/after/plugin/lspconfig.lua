local mason = require('mason')

mason.setup({})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Setup language servers.
local lspconfig = require('lspconfig')

-- Add server specific settings below. For more info see `:help lspconfig-setup`
lspconfig.lua_ls.setup({
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { 'vim' }
      }
    }
  }
})

lspconfig.rust_analyzer.setup({
  capabilities = capabilities,
  settings = {
    ['rust-analyzer'] = {},
  },
})

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic list' })

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action,
      { buffer = ev.buf, desc = 'Code action' })

    vim.keymap.set('n', 'K', vim.lsp.buf.hover,
      { buffer = ev.buf, desc = 'Hover' })

    vim.keymap.set('n', 'gd', vim.lsp.buf.definition,
      { buffer = ev.buf, desc = 'Go to definition' })

    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation,
      { buffer = ev.buf, desc = 'Go to implementation' })

    vim.keymap.set('n', 'gr', vim.lsp.buf.references,
      { buffer = ev.buf, desc = 'Go to references' })

    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename,
      { buffer = ev.buf, desc = 'Rename symbol' })

    vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end,
      { buffer = ev.buf, desc = 'Format file' })

    -- Less used LSP functionality
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
  end,
})

local luasnip = require('luasnip')
local cmp = require('cmp')
cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete {},
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  })
})
