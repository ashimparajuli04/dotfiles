return {
    {
        "folke/noice.nvim",
        event = "VeryLazy",

        dependencies = {
            "MunifTanjim/nui.nvim",
            "rcarriga/nvim-notify",
        },

        opts = {
            -- Better command-line UI
            cmdline = {
                enabled = true,
                view = "cmdline_popup",
            },

            -- Notifications
            notify = {
                enabled = true,
                view = "notify",
            },

            -- LSP UI
            lsp = {
                progress = {
                    enabled = true,
                    view = "mini",
                },

                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                },

                hover = {
                    enabled = true,
                },

                signature = {
                    enabled = true,
                },
            },

            -- Nice presets
            presets = {
                bottom_search = true,
                command_palette = true,
                long_message_to_split = true,
                inc_rename = false,
                lsp_doc_border = true,
            },
        },
    },
}
