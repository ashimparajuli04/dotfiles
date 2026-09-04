return {
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false,
		build = ":TSUpdate",

		opts = {
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"query",

				"python",
				"javascript",
				"typescript",
				"tsx",

				"html",
				"css",
				"json",

				"bash",
				"yaml",
				"toml",

				"markdown",
				"markdown_inline",

				"dockerfile",
				"sql",
				"gitignore",
				"gitcommit",
			},

			auto_install = true,

			highlight = {
				enable = true,
			},

			indent = {
				enable = true,
			},
		},
	},
}
