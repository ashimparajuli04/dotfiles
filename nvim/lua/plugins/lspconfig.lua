return {
	{
		"mason-org/mason.nvim",
		opts = {
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		},
	},

	{
		"mason-org/mason-lspconfig.nvim",
		opts = {
			ensure_installed = {
				"lua_ls",
				"basedpyright",
				"ts_ls",
				"html",
				"cssls",
				"jsonls",
				"tailwindcss",
				"bashls",
				"dockerls",
				"yamlls",
			},
		},
	},

	{
		"neovim/nvim-lspconfig",
		dependencies = { "saghen/blink.cmp" },
		config = function()
			local capabilities = require("blink.cmp").get_lsp_capabilities()

			vim.lsp.config("*", { capabilities = capabilities })

			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
					},
				},
			})

			vim.lsp.config("pyright", { enabled = false })

			vim.lsp.enable({
				"lua_ls",
				"basedpyright",
				"ts_ls",
				"html",
				"cssls",
				"jsonls",
				"tailwindcss",
				"bashls",
				"dockerls",
				"yamlls",
			})
		end,
	},
}
