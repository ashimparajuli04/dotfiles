return {
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		opts = {
			size = 15,

			hide_numbers = false,

			shade_filetypes = {},
			shade_terminals = true,
			shading_factor = 2,

			start_in_insert = true,
			insert_mappings = true,
			terminal_mappings = true,

			persist_size = true,
			persist_mode = true,

			close_on_exit = false,

			float_opts = {
				border = "rounded",
				winblend = 0,
			},
		},
	},
}
