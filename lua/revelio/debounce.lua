-- Per-key debounce using vim.loop (libuv) timers.
-- M.debounce(key, delay_ms, fn) — cancel+restart timer; fires via vim.schedule
-- M.cancel(key)
-- M.cancel_all()
local M = {}

local _timers = {}

local function stop_timer(key)
  local t = _timers[key]
  if t then
    t:stop()
    if not t:is_closing() then
      t:close()
    end
    _timers[key] = nil
  end
end

function M.debounce(key, delay_ms, fn)
  stop_timer(key)
  local timer = vim.loop.new_timer()
  _timers[key] = timer
  timer:start(delay_ms, 0, function()
    stop_timer(key)
    vim.schedule(fn)
  end)
end

function M.cancel(key)
  stop_timer(key)
end

function M.cancel_all()
  for key in pairs(_timers) do
    stop_timer(key)
  end
end

return M
