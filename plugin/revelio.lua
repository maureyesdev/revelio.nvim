-- Guard: load once and only in Neovim >= 0.10
if vim.g.loaded_revelio then
  return
end
vim.g.loaded_revelio = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("revelio.nvim requires Neovim >= 0.10", vim.log.levels.ERROR)
  return
end

-- Register all :Revelio* user commands
require("revelio.commands").setup()
