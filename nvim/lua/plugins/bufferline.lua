return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- Enable termguicolors first (important!)
      vim.opt.termguicolors = true
      vim.opt.showtabline = 2

      require("bufferline").setup({
        options = {
          hover = {
            enabled = false,
            delay = 200,
            reveal = { "close" },
          },
        },
      })
    end,
  },
}

