local map = vim.keymap.set
--- Nvim Tree
map("n", "<leader>n", "<cmd>Neotree filesystem reveal left toggle<CR>", { desc = "Toffle file explorer" })
map("n", "<leader>e", "<cmd>Neotree focus<CR>", { desc = "Neotree focus" })

--- Telescope
local builtin = require("telescope.builtin")
map("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
map("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
map("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
map("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })
map("n", "<leader>ft", builtin.colorscheme, { desc = "Telescope colorscheme picker" })

-- Formatter
map("n", "<leader>mm", function()
	require("conform").format({ bufnr = 0 })
end, { desc = "Format current buffer (conform)" })

-- copilot
map("i", "<A-l>", function()
	require("copilot.suggestion").accept()
end, { desc = "Copilot accept" })

map("i", "<A-j>", function()
	require("copilot.suggestion").next()
end, { desc = "Copilot next" })

map("i", "<A-k>", function()
	require("copilot.suggestion").prev()
end, { desc = "Copilot previous" })

map("i", "<A-h>", function()
	require("copilot.suggestion").dismiss()
end, { desc = "Copilot dismiss" })
