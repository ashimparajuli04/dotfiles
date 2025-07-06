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

--bufferline
vim.keymap.set("n", "<tab>", ":bnext<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<S-tab>", ":bprevious<CR>", { noremap = true, silent = true })
vim.keymap.set('n', '<leader>x', function()
  vim.cmd('Neotree filesystem reveal left toggle')  -- Show Neo-tree
  vim.cmd('bd')                                     -- Close current buffer
  vim.cmd('Neotree filesystem reveal left toggle')  -- Re-open Neo-tree
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-w>l', true, false, true), 'n', true)  -- Move focus right
end, { noremap = true, silent = true })


--navigation
local opts = { noremap = true, silent = true }

vim.keymap.set('n', '<C-Up>', '<C-w>k', opts)
vim.keymap.set('n', '<C-Down>', '<C-w>j', opts)
vim.keymap.set('n', '<C-Left>', '<C-w>h', opts)
vim.keymap.set('n', '<C-Right>', '<C-w>l', opts)

--resize
-- Resize up (decrease height)
vim.keymap.set('n', '<S-Up>',    ':resize -2<CR>', opts)
-- Resize down (increase height)
vim.keymap.set('n', '<S-Down>',  ':resize +2<CR>', opts)
-- Resize left (decrease width)
vim.keymap.set('n', '<S-Left>',  ':vertical resize -2<CR>', opts)
-- Resize right (increase width)
vim.keymap.set('n', '<S-Right>', ':vertical resize +2<CR>', opts)

--toggleterm
vim.keymap.set("n", "<leader>tr", ":ToggleTerm<CR>", { noremap = true, silent = true })
vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true })

--undotree
vim.keymap.set("n", "<leader>u", ":UndotreeToggle<CR>")

--zenmode
vim.keymap.set("n", "<leader>z", ":ZenMode<CR>")
