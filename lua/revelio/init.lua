-- Public API: setup(), preview(), close(), toggle(), export(), is_open()
local M = {}

local config = require("revelio.config")

--- Set up the plugin with optional user configuration.
--- @param opts table|nil
function M.setup(opts)
  config.setup(opts)
  local cfg = config.get()

  if cfg.default_keymaps then
    local km = cfg.keymaps
    vim.keymap.set("n", km.preview, M.preview, { desc = "Revelio: open markdown preview" })
    vim.keymap.set("n", km.close, M.close, { desc = "Revelio: close markdown preview" })
    vim.keymap.set("n", km.toggle, M.toggle, { desc = "Revelio: toggle markdown preview" })
    vim.keymap.set("n", km.export, M.export, { desc = "Revelio: export current document" })
  end
end

--- Open a live preview of the markdown buffer.
function M.preview()
  require("revelio.session").open()
end

--- Close the active preview session.
function M.close()
  require("revelio.session").close()
end

--- Toggle the preview for the current buffer.
function M.toggle()
  require("revelio.session").toggle()
end

--- Export the current document to a self-contained HTML file.
function M.export()
  require("revelio.session").export()
end

--- Whether a preview session is currently active.
--- @return boolean
function M.is_open()
  return require("revelio.session").current() ~= nil
end

return M
