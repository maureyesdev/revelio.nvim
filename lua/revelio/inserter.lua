local M = {}

local MAX_SCAN = 20

--- Returns the leading whitespace of a buffer line (1-indexed).
--- @param bufnr integer
--- @param lnum integer 1-indexed line number
--- @return string
function M.get_indent(bufnr, lnum)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
  return line:match("^(%s*)") or ""
end

--- Finds the line after which to insert the log statement.
--- Walks forward from lnum until open brackets are balanced.
--- @param bufnr integer
--- @param lnum integer 1-indexed line number of the variable
--- @return integer 1-indexed line after which to insert
function M.find_insert_point(bufnr, lnum)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local depth = 0
  local limit = math.min(lnum + MAX_SCAN - 1, line_count)

  for i = lnum, limit do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
    for ch in line:gmatch(".") do
      if ch == "(" or ch == "[" or ch == "{" then
        depth = depth + 1
      elseif ch == ")" or ch == "]" or ch == "}" then
        depth = depth - 1
      end
    end
    if depth <= 0 then
      return i
    end
  end

  return lnum
end

--- Inserts log_line (without indent) into bufnr after insert_lnum.
--- Moves cursor to the newly inserted line.
--- @param bufnr integer
--- @param insert_lnum integer 1-indexed line after which to insert
--- @param indent string leading whitespace
--- @param log_line string the log statement (no leading whitespace)
function M.insert_log(bufnr, insert_lnum, indent, log_line)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  -- Clamp to buffer length (handles last-line case)
  local at = math.min(insert_lnum, line_count)
  vim.api.nvim_buf_set_lines(bufnr, at, at, false, { indent .. log_line })
  -- Move cursor to the new line if this is the current buffer
  if vim.api.nvim_get_current_buf() == bufnr then
    vim.api.nvim_win_set_cursor(0, { at + 1, #indent })
  end
end

return M
