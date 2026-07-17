-- Minimal init for running tests without a full Neovim config
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")

vim.opt.runtimepath:prepend(plugin_root)

-- Stub vim.diagnostic if running in headless without display
if not vim.diagnostic then
  vim.diagnostic = {
    severity = { ERROR = 1, WARN = 2, INFO = 3, HINT = 4 },
    set = function() end,
    reset = function() end,
    get = function() return {} end,
  }
end
