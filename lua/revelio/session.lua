-- Orchestrates a single active preview session. Phase 0 stub: no server or
-- browser plumbing yet, just the shape of the public API so commands and
-- keymaps have something real to call.
local M = {}

local state = {
  current = nil, -- { bufnr } once a session is active
}

--- Open a live preview for a buffer (defaults to the current buffer).
--- @param bufnr integer|nil
function M.open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.notify("revelio: preview server not implemented yet (Phase 1)", vim.log.levels.WARN)
end

--- Close the active preview session, if any.
function M.close()
  state.current = nil
end

--- Toggle the preview for a buffer (defaults to the current buffer).
--- @param bufnr integer|nil
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if state.current and state.current.bufnr == bufnr then
    M.close()
  else
    M.open(bufnr)
  end
end

--- Export the current document to a self-contained HTML file.
function M.export()
  vim.notify("revelio: export not implemented yet (Phase 7)", vim.log.levels.WARN)
end

--- The active session's buffer, or nil if no session is active.
--- @return table|nil
function M.current()
  return state.current
end

return M
