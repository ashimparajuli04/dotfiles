local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.cursorline = true
opt.signcolumn = "yes"

opt.termguicolors = true

opt.wrap = false

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4

opt.ignorecase = true
opt.smartcase = true

opt.splitbelow = true
opt.splitright = true

opt.scrolloff = 8

opt.swapfile = false
opt.undofile = true

opt.mouse = "a"
opt.clipboard = "unnamedplus"

opt.updatetime = 250
opt.timeoutlen = 300
opt.laststatus = 3

vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"javascript",
		"typescript",
		"typescriptreact",
		"javascriptreact",
		"html",
		"css",
		"json",
		"yaml",
	},
	callback = function()
		vim.opt_local.shiftwidth = 2
		vim.opt_local.tabstop = 2
		vim.opt_local.softtabstop = 2
	end,
})
