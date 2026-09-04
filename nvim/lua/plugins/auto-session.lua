return {
	{
		"rmagatti/auto-session",
		lazy = false,

		opts = {
			auto_save = true,
			auto_restore = true,
			auto_create = true,

			-- Don't restore the last project's session
			-- when opening a different project.
			auto_restore_last_session = false,

			-- Don't save Neo-tree itself into the session.
			close_filetypes_on_save = {
				"neo-tree",
			},

			-- Don't try to save weird/special windows.
			close_unsupported_windows = true,

			-- Store sessions here.
			root_dir = vim.fn.stdpath("data") .. "/sessions/",
		},
	},
}
