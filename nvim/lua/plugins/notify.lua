return {
  "rcarriga/nvim-notify",
  config = function()
    local notify = require("notify")

    notify.setup({
      render = "compact", -- or "default", "compact", "wrapped"
      timeout = 2000,     -- how long notifications stay (in ms)
      background_colour = "#000000" -- needed for some themes (esp. transparent)
    })

    vim.notify = notify -- override default notify function

  end
}

