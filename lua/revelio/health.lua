local M = {}

local SUPPORTED_FILETYPES = {
  "javascript",
  "typescript",
  "javascriptreact",
  "typescriptreact",
  "python",
  "lua",
  "go",
}

function M.check()
  vim.health.start("revelio.nvim")

  -- Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.error("Neovim >= 0.9 required")
  end

  -- vim.treesitter available
  if vim.treesitter then
    vim.health.ok("vim.treesitter available (built-in)")
  else
    vim.health.error("vim.treesitter not available")
  end

  -- Check TS parsers per supported filetype
  for _, ft in ipairs(SUPPORTED_FILETYPES) do
    local ok = pcall(vim.treesitter.language.inspect, ft)
    if ok then
      vim.health.ok("tree-sitter parser for " .. ft .. " installed")
    else
      vim.health.warn(
        "tree-sitter parser for " .. ft .. " missing — falling back to <cword>"
      )
    end
  end
end

return M
