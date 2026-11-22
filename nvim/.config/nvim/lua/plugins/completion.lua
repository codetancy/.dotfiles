return {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    opts = {
        keymap = { preset = "enter" },
        completion = {
            documentation = { auto_show = true },
        },
        signature = { enabled = true },
        sources = {
            default = { "lsp", "path", "snippets", "buffer" },
        },
    },
}
