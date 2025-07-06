return {
  "folke/zen-mode.nvim",
  opts = {
    window = {
      backdrop = 1,
      width = vim.o.columns,
      height = vim.o.lines,
      options = {
        signcolumn = "no",
        number = false,
        relativenumber = false,
        cursorline = false,
      },
    },
  },
}

