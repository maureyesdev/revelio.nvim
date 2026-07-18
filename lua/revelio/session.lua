-- Orchestrates a single active preview session: reads the buffer, starts
-- the local server, opens the browser, and tears everything down on close.
-- A debounced watcher re-reads the buffer and broadcasts the new source
-- over SSE on every change.
local M = {}

local server = require("revelio.server")
local http = require("revelio.http")
local assets = require("revelio.assets")
local browser = require("revelio.browser")
local config = require("revelio.config")
local watcher = require("revelio.watcher")
local debounce = require("revelio.debounce")

local AUGROUP = vim.api.nvim_create_augroup("revelio_session", { clear = true })

local state = {
  current = nil, -- { bufnr, source }
  port = nil,
  browser_handle = nil, -- app-mode window handle from browser.open(), for close_app_window()
}

local function read_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

--- Resolve cfg.theme ("auto" | "light" | "dark") to a concrete "light" or
--- "dark", following &background when "auto".
local function resolve_theme(cfg)
  if cfg.theme ~= "auto" then
    return cfg.theme
  end
  return vim.o.background == "light" and "light" or "dark"
end

local function current_payload()
  return {
    source = state.current and state.current.source or "",
    theme = resolve_theme(config.get()),
  }
end

--- Ordered <link>/<script> tags injected into the static index.html, driven
--- by the CDN URLs in config so cfg.cdn.* is actually honored (rather than
--- hardcoded into the static asset). The hljs theme stylesheet carries a
--- fixed id plus both candidate hrefs as data attributes, so the client can
--- swap it for light/dark without a full page reload.
local function client_head_tags(cfg)
  local theme = resolve_theme(cfg)
  local hljs_href = theme == "light" and cfg.cdn.highlight_css_light or cfg.cdn.highlight_css_dark
  return table.concat({
    ('<link rel="stylesheet" href="%s" />'):format(cfg.cdn.github_markdown_css),
    ('<link rel="stylesheet" id="revelio-hljs-theme" href="%s" data-light-href="%s" data-dark-href="%s" />'):format(
      hljs_href,
      cfg.cdn.highlight_css_light,
      cfg.cdn.highlight_css_dark
    ),
  }, "\n")
end

local function client_script_tags(cfg)
  return table.concat({
    ('<script src="%s"></script>'):format(cfg.cdn.markdown_it),
    ('<script src="%s"></script>'):format(cfg.cdn.task_lists),
    ('<script src="%s"></script>'):format(cfg.cdn.highlight_js),
  }, "\n")
end

local function render_index(cfg)
  local html, err = assets.html()
  if not html then
    return nil, err
  end
  html = html:gsub("{{CLIENT_HEAD}}", function()
    return client_head_tags(cfg)
  end)
  html = html:gsub("{{CLIENT_SCRIPTS}}", function()
    return client_script_tags(cfg)
  end)
  local json = vim.json.encode(current_payload())
  html = html:gsub("{{INITIAL_PAYLOAD}}", function()
    return json
  end)
  return html
end

local function build_routes(cfg)
  return {
    ["GET /"] = function()
      local html, err = render_index(cfg)
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

local function on_sse_connect(client)
  if not state.current then
    return
  end
  local msg = http.sse_event("source", current_payload())
  pcall(function()
    client:write(msg)
  end)
end

--- Broadcast the cursor's current line to any connected preview so it can
--- scroll the matching rendered block into view. Debounced per buffer so a
--- burst of cursor movement collapses into a single scroll.
local function send_cursor(bufnr)
  local cfg = config.get()
  debounce.debounce("revelio-cursor:" .. bufnr, cfg.debounce_ms, function()
    if not state.current or state.current.bufnr ~= bufnr then
      return
    end
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-based
    server.broadcast("cursor", { line = row })
  end)
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

  local cfg = config.get()
  if cfg.follow_cursor and vim.tbl_contains(cfg.filetypes, vim.bo[bufnr].filetype) then
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = AUGROUP,
      buffer = bufnr,
      callback = function()
        send_cursor(bufnr)
      end,
    })
  end
end

local function detach_autocmds(bufnr)
  pcall(vim.api.nvim_clear_autocmds, { group = AUGROUP, buffer = bufnr })
  debounce.cancel("revelio-cursor:" .. bufnr)
end

-- Global (not buffer-scoped): when theme = "auto", a real ":set background="
-- flip should restyle the preview immediately rather than waiting for the
-- next open(). Registered once at module load; broadcast() is a safe no-op
-- when no server/clients exist yet.
vim.api.nvim_create_autocmd("OptionSet", {
  group = AUGROUP,
  pattern = "background",
  callback = function()
    local cfg = config.get()
    if cfg.theme == "auto" then
      server.broadcast("theme", { theme = resolve_theme(cfg) })
    end
  end,
})

--- Open a live preview for a buffer (defaults to the current buffer). If a
--- session is already active for a different buffer, retargets it instead
--- of starting a second server.
--- @param bufnr integer|nil
--- @return boolean ok
function M.open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = config.get()
  local previous_bufnr = state.current and state.current.bufnr

  state.current = { bufnr = bufnr, source = read_buffer(bufnr) }

  local port
  if server.is_running() then
    port = state.port
  else
    local result, start_err = server.start({
      host = cfg.host,
      port = cfg.port,
      routes = build_routes(cfg),
      on_sse_connect = on_sse_connect,
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
    watcher.detach(previous_bufnr)
  end
  attach_autocmds(bufnr)
  watcher.attach(bufnr, M.refresh)

  local url = ("http://%s:%d/"):format(cfg.host, port)
  local has_live_client = server.client_count() > 0

  if has_live_client then
    server.broadcast("source", current_payload())
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
  watcher.detach(state.current.bufnr)
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

--- Re-read the active session's buffer and push the new source to any
--- connected SSE clients — but only when the text actually changed, so a
--- no-op autocmd firing doesn't trigger a redundant repaint. No-op if no
--- session is active.
function M.refresh()
  if not state.current then
    return
  end
  local source = read_buffer(state.current.bufnr)
  if source == state.current.source then
    return
  end
  state.current.source = source
  server.broadcast("source", current_payload())
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
