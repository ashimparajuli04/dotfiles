require("config.lazy")
require("config.keymaps")
require("config.preferences")

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		if vim.fn.argc() == 0 then
			vim.schedule(function()
				local term = require("toggleterm.terminal").get(1)

				if term and not term:is_open() then
					term:open()
				end

				vim.cmd("Neotree show")
			end)
		end
	end,
})
