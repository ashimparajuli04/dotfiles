return {
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				-- Python
				python = { "ruff_format" },

				-- JavaScript / TypeScript
				javascript = { "prettier" },
				typescript = { "prettier" },
				javascriptreact = { "prettier" },
				typescriptreact = { "prettier" },

				-- Web
				html = { "prettier" },
				css = { "prettier" },
				scss = { "prettier" },

				-- Tailwind
				-- Tailwind files are usually handled by prettier
				-- through the Tailwind prettier plugin
				html = { "prettier" },

				-- Lua
				lua = { "stylua" },

				-- Bash
				sh = { "shfmt" },

				-- Data/config files
					json = { "prettier" },
					yaml = { "prettier" },
					markdown = { "prettier" },
			},
		},
	},
}
