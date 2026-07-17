-- Local preview HTTP server on vim.uv. Routes GET/POST to handler
-- functions; "sse" routes are upgraded to a kept-alive event stream that
-- M.broadcast() pushes to.
local uv = vim.uv or vim.loop
local http = require("revelio.http")

local M = {}

local state = {
  server = nil,
  port = nil,
  routes = {},
  clients = {},
  on_sse_connect = nil,
}

--- Whether the server is currently running.
--- @return boolean
function M.is_running()
  return state.server ~= nil
end

--- Number of connected SSE clients.
--- @return integer
function M.client_count()
  return #state.clients
end

local function send(client, status, headers, body)
  return pcall(function()
    client:write(http.response(status, headers, body))
  end)
end

local function close_client(client)
  pcall(function()
    client:close()
  end)
end

local function remove_client(client)
  for i, c in ipairs(state.clients) do
    if c == client then
      table.remove(state.clients, i)
      break
    end
  end
end

local function dispatch(client, req)
  local key = req.method .. " " .. req.path
  local handler = state.routes[key]

  if handler == "sse" then
    local ok = pcall(function()
      client:write(http.sse_headers())
    end)
    if ok then
      table.insert(state.clients, client)
      if state.on_sse_connect then
        pcall(state.on_sse_connect, client)
      end
    else
      close_client(client)
    end
    return
  end

  if type(handler) == "function" then
    local ok, status, resp_headers, body = pcall(handler, req)
    if ok then
      send(client, status, resp_headers, body)
    else
      send(client, 500, { ["Content-Type"] = "text/plain" }, "Internal Server Error")
    end
  else
    send(client, 404, { ["Content-Type"] = "text/plain" }, "Not Found")
  end

  close_client(client)
end

--- Start the preview server. Idempotent: calling start() while already
--- running returns the existing port without creating a new server.
--- @param opts { host: string|nil, port: integer|nil, routes: table|nil, on_sse_connect: function|nil }|nil
---   on_sse_connect(client) fires right after a client upgrades on an "sse"
---   route, so callers can push a connect-time snapshot to that one client.
--- @return table|nil result { port = integer }
--- @return string|nil err
function M.start(opts)
  opts = opts or {}
  if state.server then
    return { port = state.port }
  end

  local host = opts.host or "127.0.0.1"
  local port = opts.port or 0
  state.routes = opts.routes or {}
  state.clients = {}
  state.on_sse_connect = opts.on_sse_connect

  local server = uv.new_tcp()

  local bind_ok, bind_err = pcall(function()
    server:bind(host, port)
  end)
  if not bind_ok then
    pcall(function()
      server:close()
    end)
    return nil, tostring(bind_err)
  end

  local listen_ok, listen_err = pcall(function()
    server:listen(128, function(err)
      if err then
        return
      end

      local client = uv.new_tcp()
      server:accept(client)

      local buf = ""
      client:read_start(function(read_err, chunk)
        if read_err or not chunk then
          vim.schedule(function()
            remove_client(client)
            close_client(client)
          end)
          return
        end

        buf = buf .. chunk
        local req, perr = http.parse_request(buf)

        if req then
          buf = ""
          vim.schedule(function()
            dispatch(client, req)
          end)
        elseif perr == "malformed" then
          buf = ""
          vim.schedule(function()
            send(client, 400, { ["Content-Type"] = "text/plain" }, "Bad Request")
            close_client(client)
          end)
        end
        -- perr == "incomplete" -> keep buffering
      end)
    end)
  end)

  if not listen_ok then
    pcall(function()
      server:close()
    end)
    return nil, tostring(listen_err)
  end

  state.server = server
  state.port = server:getsockname().port

  return { port = state.port }
end

--- Stop the server and close all connected clients.
function M.stop()
  if not state.server then
    return
  end
  for _, c in ipairs(state.clients) do
    close_client(c)
  end
  state.clients = {}
  pcall(function()
    state.server:close()
  end)
  state.server = nil
  state.port = nil
  state.on_sse_connect = nil
end

--- Push an SSE event to all connected clients; clients that fail to
--- write (e.g. browser tab closed) are dropped from the list.
--- @param event string
--- @param data_tbl table
function M.broadcast(event, data_tbl)
  if #state.clients == 0 then
    return
  end
  local msg = http.sse_event(event, data_tbl)
  local alive = {}
  for _, c in ipairs(state.clients) do
    local ok = pcall(function()
      c:write(msg)
    end)
    if ok then
      table.insert(alive, c)
    else
      close_client(c)
    end
  end
  state.clients = alive
end

return M
