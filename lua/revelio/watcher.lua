-- Attaches a debounced autocmd to a buffer so an active preview session
-- re-renders shortly after the user stops typing.
local M = {}

local debounce = require("revelio.debounce")

local attached = {} -- bufnr -> augroup id

--- Attach a debounced change watcher to a buffer.
--- @param bufnr integer
--- @param on_change function called (debounced) after a watched event fires
--- @param events string[]|nil autocmd events to watch; defaults to
---   { "TextChanged", "TextChangedI" }.
function M.attach(bufnr, on_change, events)
  if attached[bufnr] then
    return
  end

  events = events or { "TextChanged", "TextChangedI" }
  local cfg = require("revelio.config").get()
  local group = vim.api.nvim_create_augroup(("revelio_watcher_%d"):format(bufnr), { clear = true })

  vim.api.nvim_create_autocmd(events, {
    group = group,
    buffer = bufnr,
    callback = function()
      debounce.debounce("revelio:" .. bufnr, cfg.debounce_ms, on_change)
    end,
  })

  attached[bufnr] = group
end

--- Detach the change watcher from a buffer and cancel any pending debounce.
--- @param bufnr integer
function M.detach(bufnr)
  local group = attached[bufnr]
  if not group then
    return
  end
  pcall(vim.api.nvim_del_augroup_by_id, group)
  debounce.cancel("revelio:" .. bufnr)
  attached[bufnr] = nil
end

--- Whether a watcher is currently attached to a buffer.
--- @param bufnr integer
--- @return boolean
function M.is_attached(bufnr)
  return attached[bufnr] ~= nil
end

return M
