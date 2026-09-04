return {
	{
		"zbirenbaum/copilot.lua",
		lazy = false,
		build = ":Copilot auth",
		opts = {
			suggestion = { enabled = true,
			auto_trigger = true,
				
		},
			panel = { enabled = false },
		},
		config = function(_, opts)
			require("copilot").setup(opts)

			vim.api.nvim_set_hl(0, "CopilotSuggestion", {
				fg = "#6e738d",
			})
		end,
	},
}
