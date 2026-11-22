vim.lsp.enable({ "lua_ls", "rust_analyzer", "clangd" })

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = args.buf, desc = "Go to definition" })
    end,
})
