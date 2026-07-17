local server = require("revelio.server")
local uv = vim.uv or vim.loop

local function get(port, path)
  local received = ""
  local done = false
  local client = uv.new_tcp()
  client:connect("127.0.0.1", port, function(conn_err)
    if conn_err then
      done = true
      return
    end
    client:write(("GET %s HTTP/1.1\r\nHost: x\r\n\r\n"):format(path))
    client:read_start(function(_, chunk)
      if chunk then
        received = received .. chunk
      else
        done = true
        pcall(function()
          client:close()
        end)
      end
    end)
  end)
  vim.wait(2000, function()
    return done
  end, 10)
  return received
end

describe("revelio.server", function()
  after_each(function()
    server.stop()
  end)

  it("start({port=0}) returns a real OS-assigned port", function()
    local result, err = server.start({ port = 0, routes = {} })
    assert.is_nil(err)
    assert.is_not_nil(result)
    assert.is_true(result.port > 0)
  end)

  it("serves a GET route and returns the handler's response body", function()
    local result = server.start({
      port = 0,
      routes = {
        ["GET /"] = function()
          return 200, { ["Content-Type"] = "text/plain" }, "hello revelio"
        end,
      },
    })

    local received = get(result.port, "/")
    assert.matches("200 OK", received)
    assert.matches("hello revelio", received)
  end)

  it("returns 404 for unregistered routes", function()
    local result = server.start({ port = 0, routes = {} })
    local received = get(result.port, "/nope")
    assert.matches("404", received)
  end)

  it("stop() frees the port so a restart on the same port succeeds", function()
    local first = server.start({ port = 0, routes = {} })
    local fixed_port = first.port
    server.stop()

    local second, err = server.start({ port = fixed_port, routes = {} })
    assert.is_nil(err)
    assert.equals(fixed_port, second.port)
  end)

  it("is idempotent on a double start", function()
    local first = server.start({ port = 0, routes = {} })
    local second = server.start({ port = 0, routes = {} })
    assert.equals(first.port, second.port)
  end)

  it("is_running() reflects server state", function()
    assert.is_false(server.is_running())
    server.start({ port = 0, routes = {} })
    assert.is_true(server.is_running())
    server.stop()
    assert.is_false(server.is_running())
  end)

  it("invokes on_sse_connect and streams its event to the connecting client", function()
    local http = require("revelio.http")
    local result = server.start({
      port = 0,
      routes = { ["GET /events"] = "sse" },
      on_sse_connect = function(client)
        client:write(http.sse_event("source", { hello = "world" }))
      end,
    })

    local received = ""
    local got_event = false
    local client = uv.new_tcp()
    client:connect("127.0.0.1", result.port, function(conn_err)
      if conn_err then
        return
      end
      client:write("GET /events HTTP/1.1\r\nHost: x\r\n\r\n")
      client:read_start(function(_, chunk)
        if chunk then
          received = received .. chunk
          if received:find("event: source", 1, true) then
            got_event = true
          end
        end
      end)
    end)

    vim.wait(2000, function()
      return got_event
    end, 10)
    pcall(function()
      client:close()
    end)

    assert.matches("text/event%-stream", received)
    assert.matches("event: source", received)
    assert.matches('"hello":"world"', received)
  end)

  it("client_count() reflects connected SSE clients", function()
    local result = server.start({ port = 0, routes = { ["GET /events"] = "sse" } })
    assert.equals(0, server.client_count())

    local client = uv.new_tcp()
    client:connect("127.0.0.1", result.port, function(conn_err)
      if conn_err then
        return
      end
      client:write("GET /events HTTP/1.1\r\nHost: x\r\n\r\n")
    end)

    vim.wait(2000, function()
      return server.client_count() == 1
    end, 10)
    assert.equals(1, server.client_count())
    pcall(function()
      client:close()
    end)
  end)
end)
