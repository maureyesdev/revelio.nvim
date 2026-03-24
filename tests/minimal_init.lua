local plenary_path = "/tmp/plenary.nvim"

-- Bootstrap plenary if not present
if vim.fn.isdirectory(plenary_path) == 0 then
  vim.fn.system({
    "git", "clone", "--depth=1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary_path,
  })
end

vim.opt.runtimepath:prepend(plenary_path)
vim.opt.runtimepath:prepend(vim.fn.getcwd())
