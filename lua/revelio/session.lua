-- Orchestrates a single active preview session: starts the local server,
-- opens the browser, and tears everything down on close. Buffer content
-- reading and live sync land in Phase 2/3.
local M = {}

local server = require("revelio.server")
local assets = require("revelio.assets")
local browser = require("revelio.browser")
local config = require("revelio.config")

local AUGROUP = vim.api.nvim_create_augroup("revelio_session", { clear = true })

local state = {
  current = nil, -- { bufnr }
  port = nil,
  browser_handle = nil, -- app-mode window handle from browser.open(), for close_app_window()
}

local function build_routes()
  return {
    ["GET /"] = function()
      local html, err = assets.html()
      if not html then
        return 500, { ["Content-Type"] = "text/plain" }, "revelio: " .. tostring(err)
      end
      return 200, { ["Content-Type"] = "text/html" }, html
    end,

    ["GET /app.js"] = function()
      local js, err = assets.js()
      if not js then
        return 500, { ["Content-Type"] = "text/plain" }, "revelio: " .. tostring(err)
      end
      return 200, { ["Content-Type"] = "application/javascript" }, js
    end,

    ["GET /app.css"] = function()
      local css, err = assets.css()
      if not css then
        return 500, { ["Content-Type"] = "text/plain" }, "revelio: " .. tostring(err)
      end
      return 200, { ["Content-Type"] = "text/css" }, css
    end,

    ["GET /events"] = "sse",
  }
end

local function attach_autocmds(bufnr)
  vim.api.nvim_create_autocmd({ "BufUnload", "VimLeavePre" }, {
    group = AUGROUP,
    buffer = bufnr,
    once = true,
    callback = function()
      M.close()
    end,
  })
end

local function detach_autocmds(bufnr)
  pcall(vim.api.nvim_clear_autocmds, { group = AUGROUP, buffer = bufnr })
end

--- Open a live preview for a buffer (defaults to the current buffer). If a
--- session is already active for a different buffer, retargets it instead
--- of starting a second server.
--- @param bufnr integer|nil
--- @return boolean ok
function M.open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = config.get()
  local previous_bufnr = state.current and state.current.bufnr

  state.current = { bufnr = bufnr }

  local port
  if server.is_running() then
    port = state.port
  else
    local result, start_err = server.start({
      host = cfg.host,
      port = cfg.port,
      routes = build_routes(),
    })
    if not result then
      vim.notify("revelio: failed to start server: " .. tostring(start_err), vim.log.levels.ERROR)
      state.current = nil
      return false
    end
    port = result.port
    state.port = port
  end

  if previous_bufnr and previous_bufnr ~= bufnr then
    detach_autocmds(previous_bufnr)
  end
  attach_autocmds(bufnr)

  local url = ("http://%s:%d/"):format(cfg.host, port)
  local has_live_client = server.client_count() > 0

  if has_live_client then
    vim.notify(("revelio: preview retargeted (%s)"):format(url), vim.log.levels.INFO)
  elseif cfg.auto_open_browser then
    if state.browser_handle then
      browser.close_app_window(state.browser_handle)
    end
    local ok, open_err, handle = browser.open(url, cfg)
    state.browser_handle = handle
    if not ok then
      vim.notify(("revelio: %s — open manually: %s"):format(open_err, url), vim.log.levels.WARN)
    end
  else
    vim.notify(("revelio: preview running at %s"):format(url), vim.log.levels.INFO)
  end

  return true
end

--- Close the active preview session, if any.
function M.close()
  if not state.current then
    return
  end
  detach_autocmds(state.current.bufnr)
  if state.browser_handle then
    browser.close_app_window(state.browser_handle)
    state.browser_handle = nil
  end
  server.stop()
  state.current = nil
  state.port = nil
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
  if not state.current then
    return nil
  end
  return { bufnr = state.current.bufnr }
end

--- The port the local server is bound to, or nil if not running.
--- @return integer|nil
function M.port()
  return state.port
end

return M
