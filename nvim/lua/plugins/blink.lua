return {
	{
		"saghen/blink.cmp",

		dependencies = {
			"saghen/blink.lib",
		},

		version = "*",

		build = "cargo build --release --locked",

		opts = function()
			return {
				keymap = require("config.keymaps").cmp_keymaps,

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
			}
		end,
	},
}