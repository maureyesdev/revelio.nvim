-- All :Revelio* user commands.
-- Called once from plugin/revelio.lua after the version guard.
local M = {}

local function revelio()
  return require("revelio")
end

function M.setup()
  vim.api.nvim_create_user_command("RevelioPreview", function()
    revelio().preview()
  end, { desc = "Open a live markdown preview" })

  vim.api.nvim_create_user_command("RevelioClose", function()
    revelio().close()
  end, { desc = "Close the active markdown preview" })

  vim.api.nvim_create_user_command("RevelioToggle", function()
    revelio().toggle()
  end, { desc = "Toggle the markdown preview" })

  vim.api.nvim_create_user_command("RevelioExport", function()
    revelio().export()
  end, { desc = "Export the current document to a self-contained HTML file" })

  vim.api.nvim_create_user_command("RevelioInfo", function()
    local cfg = require("revelio.config").get()
    vim.notify(vim.inspect(cfg), vim.log.levels.INFO)
  end, { desc = "Print current revelio config" })
end

return M
