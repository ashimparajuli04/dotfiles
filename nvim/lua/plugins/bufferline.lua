return {
	{
		"akinsho/bufferline.nvim",
		version = "*",

		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},

		opts = {
			options = {
				mode = "buffers",

				-- Don't show bufferline for a single buffer
				always_show_bufferline = false,

				-- Icons
				show_buffer_icons = true,
				show_buffer_close_icons = true,
				show_close_icon = true,

				-- Don't show numbers
				numbers = "none",

				-- Buffer separators
				separator_style = "slant",

				-- Current buffer indicator
				indicator = {
					style = "icon",
					icon = "▎",
				},

				-- Modified buffer
				modified_icon = "●",

				-- Close icon
				close_icon = "󰅖",
				buffer_close_icon = "󰅖",

				-- Mouse
				left_mouse_command = "buffer %d",
				right_mouse_command = "bdelete! %d",

				-- LSP diagnostics
				diagnostics = "nvim_lsp",

				diagnostics_indicator = function(_, _, diagnostics_dict)
					local s = ""

					if diagnostics_dict.error then
						s = s .. "  " .. diagnostics_dict.error
					end

					if diagnostics_dict.warning then
						s = s .. "  " .. diagnostics_dict.warning
					end

					return s
				end,

				-- Keep bufferline aligned with Neo-tree
				offsets = {
					{
						filetype = "neo-tree",
						text = "File Explorer",
						text_align = "left",
						separator = true,
					},
				},

				-- Show close icon only when hovering
				hover = {
					enabled = true,
					delay = 200,
					reveal = { "close" },
				},
			},
		},
	},
}
