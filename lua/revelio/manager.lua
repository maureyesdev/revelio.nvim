local M = {}

local COMMENT_CHARS = {
  javascript      = "//",
  typescript      = "//",
  javascriptreact = "//",
  typescriptreact = "//",
  python          = "#",
  lua             = "--",
  go              = "//",
}

--- Returns lines in the buffer that contain the revelio prefix.
--- @param bufnr integer
--- @param cfg table
--- @return table[] array of { lnum: integer (1-indexed), line: string, commented: boolean }
function M.find_revelio_lines(bufnr, cfg)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local result = {}
  for i, line in ipairs(lines) do
    if line:find(cfg.prefix, 1, true) then
      -- Check if line is commented (after leading whitespace)
      local stripped = line:match("^%s*(.*)")
      local commented = stripped:match("^//") ~= nil
        or stripped:match("^#") ~= nil
        or stripped:match("^%-%-") ~= nil
      result[#result + 1] = { lnum = i, line = line, commented = commented }
    end
  end
  return result
end

--- Deletes all revelio log lines from the buffer.
--- @param bufnr integer
--- @param cfg table
function M.delete_logs(bufnr, cfg)
  local revelio_lines = M.find_revelio_lines(bufnr, cfg)
  -- Process in reverse to preserve line numbers
  for i = #revelio_lines, 1, -1 do
    local lnum = revelio_lines[i].lnum
    vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, {})
  end
end

--- Comments all active (non-commented) revelio log lines.
--- @param bufnr integer
--- @param cfg table
function M.comment_logs(bufnr, cfg)
  local ft = vim.bo[bufnr].filetype
  local comment_char = COMMENT_CHARS[ft] or "//"
  local revelio_lines = M.find_revelio_lines(bufnr, cfg)

  for _, entry in ipairs(revelio_lines) do
    if not entry.commented then
      local line = entry.line
      local indent, rest = line:match("^(%s*)(.*)")
      local new_line = indent .. comment_char .. " " .. rest
      vim.api.nvim_buf_set_lines(bufnr, entry.lnum - 1, entry.lnum, false, { new_line })
    end
  end
end

--- Uncomments all commented revelio log lines.
--- @param bufnr integer
--- @param cfg table
function M.uncomment_logs(bufnr, cfg)
  local revelio_lines = M.find_revelio_lines(bufnr, cfg)

  for _, entry in ipairs(revelio_lines) do
    if entry.commented then
      local line = entry.line
      -- Strip leading comment chars: //, #, or --  (optionally followed by a space)
      local new_line = line:gsub("^(%s*)(%/%/ ?)(.*)", "%1%3")
        :gsub("^(%s*)(# ?)(.*)", "%1%3")
        :gsub("^(%s*)(%-%-? ?)(.*)", "%1%3")
      -- If none matched, fallback to original (shouldn't happen)
      if new_line == line then
        local indent, rest = line:match("^(%s*)(.*)")
        rest = rest:gsub("^//%s?", ""):gsub("^#%s?", ""):gsub("^%-%-%s?", "")
        new_line = indent .. rest
      end
      vim.api.nvim_buf_set_lines(bufnr, entry.lnum - 1, entry.lnum, false, { new_line })
    end
  end
end

--- Updates the filename:line metadata inside all revelio log lines.
--- For each revelio line at buffer line N, assumes the logged variable is on line N-1.
--- @param bufnr integer
--- @param cfg table
function M.correct_logs(bufnr, cfg)
  local revelio_lines = M.find_revelio_lines(bufnr, cfg)
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local basename = vim.fn.fnamemodify(buf_name, ":t")

  for _, entry in ipairs(revelio_lines) do
    local var_lnum = entry.lnum - 1  -- the variable is expected on the line above
    -- Replace filename:digits pattern inside the quoted message
    local new_line = entry.line:gsub(
      "([%w%.%-_]+:%d+)",
      basename .. ":" .. tostring(var_lnum)
    )
    if new_line ~= entry.line then
      vim.api.nvim_buf_set_lines(bufnr, entry.lnum - 1, entry.lnum, false, { new_line })
    end
  end
end

return M
