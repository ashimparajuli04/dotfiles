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
				"pyright",
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
		config = function()
			-- Lua
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
					},
				},
			})
			vim.lsp.enable("lua_ls")

			-- Python
			vim.lsp.config("pyright", {})
			vim.lsp.enable("pyright")

			-- TypeScript / JavaScript
			vim.lsp.config("ts_ls", {})
			vim.lsp.enable("ts_ls")

			-- HTML
			vim.lsp.config("html", {})
			vim.lsp.enable("html")

			-- CSS
			vim.lsp.config("cssls", {})
			vim.lsp.enable("cssls")

			-- JSON
			vim.lsp.config("jsonls", {})
			vim.lsp.enable("jsonls")

			-- Tailwind
			vim.lsp.config("tailwindcss", {})
			vim.lsp.enable("tailwindcss")

			-- Bash 
			vim.lsp.config("bashls", {})
			vim.lsp.enable("bashls")

			-- Docker
			vim.lsp.config("dockerls", {})
			vim.lsp.enable("dockerls")

			-- YAML
			vim.lsp.config("yamlls", {})
			vim.lsp.enable("yamlls")
		end,
	},
}
