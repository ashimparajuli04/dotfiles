require("config.lazy")
require("config.keymaps")
require("config.preferences")

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		if vim.fn.argc() == 0 then
			vim.schedule(function()
                vim.cmd("ToggleTerm")
				vim.cmd("Neotree show")
                vim.cmd("wincmd p")
			end)
		end
	end,
})
