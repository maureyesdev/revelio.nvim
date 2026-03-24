if vim.g.loaded_revelio then
  return
end
vim.g.loaded_revelio = true

if vim.fn.has("nvim-0.9") == 0 then
  vim.notify("revelio.nvim requires Neovim >= 0.9", vim.log.levels.ERROR)
  return
end

local revelio = require("revelio")
revelio.setup()

vim.api.nvim_create_user_command("RevelioLog", function()
  revelio.log()
end, { desc = "Insert log for variable under cursor" })

vim.api.nvim_create_user_command("RevelioDelete", function()
  revelio.delete()
end, { desc = "Delete all revelio logs in buffer" })

vim.api.nvim_create_user_command("RevelioComment", function()
  revelio.comment()
end, { desc = "Comment all revelio logs in buffer" })

vim.api.nvim_create_user_command("RevelioUncomment", function()
  revelio.uncomment()
end, { desc = "Uncomment all revelio logs in buffer" })

vim.api.nvim_create_user_command("RevelioCorrect", function()
  revelio.correct()
end, { desc = "Correct all revelio log metadata" })
