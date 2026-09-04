return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons", -- optional, but recommended
		},
		lazy = false, -- neo-tree will lazily load itself

		opts = {
            enable_git_status = true,
            enable_diagnostics = true,
			default_component_configs = {
				indent = {
					with_expanders = true,
					expander_collapsed = "",
					expander_expanded = "",
				},
				git_status = {
					symbols = {
						added = "+",
						modified = "~",
						deleted = "x",
						renamed = "→",
						untracked = "?",
						ignored = "◌",
						unstaged = "!",
						staged = "✓",
						conflict = "",
					},
				},
			},

			window = {
				width = 30,
			},
			filesystem = {
				follow_current_file = {
					enabled = true,
                    leave_dirs_open = true,
				},
				filtered_items = {
					hide_dotfiles = false,
				},
			},
		},
	},
}
