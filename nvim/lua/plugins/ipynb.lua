return {
    {
        "ajbucci/ipynb.nvim",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "neovim/nvim-lspconfig",
            "nvim-tree/nvim-web-devicons",
            "folke/snacks.nvim",
        },
        opts = {
            kernel = {
                auto_connect = false,
                show_status = true,
            },

            images = {
                enabled = true,
            },

            border_hints = {
                enabled = true,
                show_on_hover = true,
                show_on_edit = true,
            },

            folding = {
                hide_output = false,
            },

            format = {
                enabled = true,
                trailing_blank_lines = 0,
            },
        },
    },
}
