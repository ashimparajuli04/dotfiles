return {
	{
		"nvimdev/dashboard-nvim",
		event = "VimEnter",

		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},

		opts = {
			theme = "doom",

			config = {

				center = {
					{
						icon = "󰈞 ",
						desc = "Find File",
						key = "f",
						key_format = " [%s]",
						action = "Telescope find_files",
					},

					{
						icon = "󰱼 ",
						desc = "Find Text",
						key = "g",
						key_format = " [%s]",
						action = "Telescope live_grep",
					},

					{
						icon = "󰒲 ",
						desc = "Lazy",
						key = "l",
						key_format = " [%s]",
						action = "Lazy",
					},

					{
						icon = "󰑓 ",
						desc = "Update",
						key = "u",
						key_format = " [%s]",
						action = "Lazy update",
					},

					{
						icon = "󰈆 ",
						desc = "Quit",
						key = "q",
						key_format = " [%s]",
						action = "qa",
					},
				},

				footer = {
					"",
					"Have a productive session.",
				},

				vertical_center = true,
			},
		},
	},
}
