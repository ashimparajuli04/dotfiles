return {
	{
		"okuuva/auto-save.nvim",
		event = { "InsertLeave","TextChanged" }, --TextChanged
		opts = {
			enabled = true,
			debounce_delay = 500,
		},
	},
}
