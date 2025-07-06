--Set leader
vim.cmd("let mapleader = ' '")

--Neotree keybinds
vim.keymap.set("n", "<C-n>", ":Neotree filesystem reveal left toggle<CR>")
vim.keymap.set("n", "<leader>e", ":Neotree focus<CR>")

--Copy/Paste keybinds}
vim.keymap.set("x", "y", '"+y', { noremap = true, silent = false })

--Telescope
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>")
vim.keymap.set("n", "<leader>cs", ":Telescope colorscheme<CR>")
vim.keymap.set("n", "<leader>of", ":Telescope oldfiles<CR>")
vim.keymap.set("n", "<leader>fw", ":Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>lp", ":Telescope lsp_document_symbols<CR>")
