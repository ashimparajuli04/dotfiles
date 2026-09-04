return {
    {
        "rachartier/tiny-inline-diagnostic.nvim",
        event = "VeryLazy",
        priority = 1000,

        opts = {
            preset = "ghost",

            options = {
                -- Show the actual diagnostic message
                add_messages = {
                    messages = true,
                    display_count = false,
                    show_multiple_glyphs = true,
                },

                -- Show diagnostics even when cursor isn't on the line
                multilines = {
                    enabled = true,
                    always_show = true,
                },

                -- Show diagnostics while you're typing
                enable_on_insert = true,

                -- Show all diagnostics on the current line
                show_all_diags_on_cursorline = true,

                -- Wrap long diagnostic messages
                overflow = {
                    mode = "wrap",
                    padding = 0,
                },

                -- Wrap messages after this many characters
                softwrap = 40,

                -- Show related LSP diagnostics
                show_related = {
                    enabled = true,
                    max_count = 3,
                },

                -- Keep diagnostics responsive
                throttle = 20,

                -- Keep it above other virtual text
                virt_texts = {
                    priority = 2048,
                },
            },
        },

        config = function(_, opts)
            require("tiny-inline-diagnostic").setup(opts)

            -- Disable Neovim's own diagnostics to prevent duplicates
            vim.diagnostic.config({
                virtual_text = false,
            })
        end,
    },
}
