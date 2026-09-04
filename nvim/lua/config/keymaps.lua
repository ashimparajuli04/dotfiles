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
map("n", "<leader>fr", function()
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

-- toggleterm
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Move to left window" })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Move to bottom window" })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Move to top window" })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Move to right window" })

-- window resize
map("n", "<A-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<A-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<A-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<A-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- window navigation
map("n", "<C-Left>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-Down>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-Up>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-Right>", "<C-w>l", { desc = "Move to right window" })

-- bufferline
map("n", "<A-j>", "<cmd>BufferLineCyclePrev<cr>", {
	desc = "Previous buffer",
})

map("n", "<A-k>", "<cmd>BufferLineCycleNext<cr>", {
	desc = "Next buffer",
})

map("n", "<A-p>", "<cmd>BufferLinePick<cr>", {
	desc = "Pick buffer",
})

map("n", "<A-w>", "<cmd>BufferLineCyclePrev<cr><cmd>bdelete #<cr>", {
	desc = "Close buffer",
})

-- code actions
map("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", { desc = "Code action" })
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gr", vim.lsp.buf.references, { desc = "Find references" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
