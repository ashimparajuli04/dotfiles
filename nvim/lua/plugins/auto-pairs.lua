return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		opts = {
			check_ts = true,

			fast_wrap = {
				enabled = true,
				map = "<C-e>",
			},
		},
	},
}
