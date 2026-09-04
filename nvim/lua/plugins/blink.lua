return {
	{
		"saghen/blink.cmp",

		dependencies = {
			"saghen/blink.lib",
		},

		version = "*",

		build = "cargo build --release --locked",

		opts = {
			keymap = {
				preset = "default",

				["<C-space>"] = {
					"show",
					"show_documentation",
					"hide_documentation",
				},

				["<C-e>"] = { "hide" },

				["<CR>"] = { "accept", "fallback" },

				["<Tab>"] = {
					"select_next",
					"snippet_forward",
					"fallback",
				},

				["<S-Tab>"] = {
					"select_prev",
					"snippet_backward",
					"fallback",
				},

				["<C-n>"] = { "select_next" },
				["<C-p>"] = { "select_prev" },
			},

			appearance = {
				nerd_font_variant = "mono",
			},

			sources = {
				default = {
					"lsp",
					"path",
					"snippets",
					"buffer",
				},
			},

			completion = {
				list = {
					selection = {
						preselect = true,
						auto_insert = false,
					},
				},
			},
		},
	},
}
