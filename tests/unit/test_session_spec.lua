local session = require("revelio.session")
local config = require("revelio.config")
local server = require("revelio.server")
local browser = require("revelio.browser")

local uv = vim.uv or vim.loop

local function make_markdown_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

--- GET path on the session's server; returns the raw HTTP response text
--- (status line + headers + body).
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

--- Connect to the SSE stream and keep reading; returns the client handle
--- and a getter for everything received so far.
local function connect_sse(port)
  local client = uv.new_tcp()
  local received = ""
  client:connect("127.0.0.1", port, function(conn_err)
    if conn_err then
      return
    end
    client:write("GET /events HTTP/1.1\r\nHost: x\r\n\r\n")
    client:read_start(function(_, chunk)
      if chunk then
        received = received .. chunk
      end
    end)
  end)
  return client, function()
    return received
  end
end

describe("revelio.session", function()
  before_each(function()
    -- Never actually spawn a browser during tests.
    config.setup({ port = 0, auto_open_browser = false })
  end)

  after_each(function()
    session.close()
  end)

  it("current() is nil when no session is active", function()
    assert.is_nil(session.current())
  end)

  it("open() starts the server and tracks the buffer", function()
    local bufnr = make_markdown_buffer({ "# Hello", "", "world" })
    local ok = session.open(bufnr)
    assert.is_true(ok)
    assert.is_true(server.is_running())

    local current = session.current()
    assert.is_not_nil(current)
    assert.equals(bufnr, current.bufnr)
  end)

  it("close() stops the server and clears current()", function()
    local bufnr = make_markdown_buffer({ "# Hello" })
    session.open(bufnr)
    session.close()
    assert.is_nil(session.current())
    assert.is_false(server.is_running())
  end)

  it("toggle() opens then closes the same buffer", function()
    local bufnr = make_markdown_buffer({ "# Hello" })
    session.toggle(bufnr)
    assert.is_not_nil(session.current())
    session.toggle(bufnr)
    assert.is_nil(session.current())
  end)

  it("open() on a second buffer retargets without restarting the server", function()
    local buf1 = make_markdown_buffer({ "# One" })
    local buf2 = make_markdown_buffer({ "# Two" })

    session.open(buf1)
    assert.equals(buf1, session.current().bufnr)

    session.open(buf2)
    assert.is_true(server.is_running())
    assert.equals(buf2, session.current().bufnr)
  end)

  describe("GET /", function()
    it("embeds the buffer's raw source in the initial payload", function()
      local bufnr = make_markdown_buffer({ "# Title", "", "Some *text*." })
      session.open(bufnr)

      local received = get(session.port(), "/")
      assert.matches("200 OK", received)
      assert.matches("Some %*text%*%.", received)
    end)

    it("injects the configured CDN script/link tags", function()
      local bufnr = make_markdown_buffer({ "# Title" })
      session.open(bufnr)

      local received = get(session.port(), "/")
      assert.matches("markdown%-it@14", received)
      assert.matches("markdown%-it%-task%-lists@2", received)
      assert.matches("github%-markdown%-css@5", received)
      assert.matches("cdn%-release@11", received)
      assert.matches('id="revelio%-hljs%-theme"', received)
    end)
  end)

  describe("SSE", function()
    it("on_sse_connect pushes the current source to a newly connected client", function()
      local bufnr = make_markdown_buffer({ "# Title", "hello" })
      session.open(bufnr)

      local client, get_received = connect_sse(session.port())
      vim.wait(1000, function()
        return get_received():find("event: source", 1, true) ~= nil
      end, 10)

      local received = get_received()
      assert.matches("event: source", received)
      assert.matches("hello", received)

      pcall(function()
        client:close()
      end)
    end)
  end)

  describe("live sync (refresh)", function()
    it("refresh() is a no-op when no session is active", function()
      session.refresh()
      assert.is_nil(session.current())
    end)

    it("refresh() broadcasts the new source when the buffer changed", function()
      local bufnr = make_markdown_buffer({ "# Title", "before" })
      session.open(bufnr)

      local client, get_received = connect_sse(session.port())
      vim.wait(1000, function()
        return server.client_count() == 1
      end, 10)

      vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "after" })
      session.refresh()

      vim.wait(1000, function()
        return get_received():find("after", 1, true) ~= nil
      end, 10)

      assert.matches("after", get_received())

      pcall(function()
        client:close()
      end)
    end)

    it("refresh() does not broadcast when the buffer text is unchanged", function()
      local bufnr = make_markdown_buffer({ "# Title", "same" })
      session.open(bufnr)

      local client, get_received = connect_sse(session.port())
      vim.wait(1000, function()
        return get_received():find("event: source", 1, true) ~= nil
      end, 10)

      local before = get_received()
      session.refresh()
      vim.wait(100)
      assert.equals(before, get_received())

      pcall(function()
        client:close()
      end)
    end)

    it("watcher.attach fires session.refresh (debounced) after a TextChanged edit", function()
      require("revelio.config").setup({ port = 0, auto_open_browser = false, debounce_ms = 10 })
      local bufnr = make_markdown_buffer({ "# Title", "one" })
      session.open(bufnr)

      local client, get_received = connect_sse(session.port())
      vim.wait(1000, function()
        return server.client_count() == 1
      end, 10)

      vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "two" })
      vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })

      vim.wait(500, function()
        return get_received():find("two", 1, true) ~= nil
      end, 10)

      assert.matches("two", get_received())

      pcall(function()
        client:close()
      end)
    end)
  end)

  describe("scroll sync (cursor)", function()
    it("broadcasts a cursor SSE event on CursorMoved in a markdown buffer with follow_cursor enabled", function()
      config.setup({ port = 0, auto_open_browser = false, follow_cursor = true, debounce_ms = 10 })
      local bufnr = make_markdown_buffer({ "# Title", "line two", "line three" })
      vim.api.nvim_set_current_buf(bufnr)
      session.open(bufnr)

      local client, get_received = connect_sse(session.port())
      vim.wait(1000, function()
        return server.client_count() == 1
      end, 10)

      vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- 1-based; line three
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })

      vim.wait(500, function()
        return get_received():find("event: cursor", 1, true) ~= nil
      end, 10)

      local received = get_received()
      assert.matches("event: cursor", received)
      assert.matches('"line":2', received) -- 0-based

      pcall(function()
        client:close()
      end)
    end)

    it("does not attach a CursorMoved watcher when follow_cursor = false", function()
      config.setup({ port = 0, auto_open_browser = false, follow_cursor = false, debounce_ms = 10 })
      local bufnr = make_markdown_buffer({ "# Title", "line two" })
      vim.api.nvim_set_current_buf(bufnr)
      session.open(bufnr)

      local client, get_received = connect_sse(session.port())
      vim.wait(300, function()
        return server.client_count() == 1
      end, 10)

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
      vim.wait(200)

      assert.is_nil(get_received():find("event: cursor", 1, true))

      pcall(function()
        client:close()
      end)
    end)
  end)

  describe("browser window lifecycle (regression: stale reopen / ghost window)", function()
    local orig_open, orig_close

    before_each(function()
      orig_open = browser.open
      orig_close = browser.close_app_window
    end)

    after_each(function()
      browser.open = orig_open
      browser.close_app_window = orig_close
    end)

    it("opens a browser window on the very first preview", function()
      local calls = 0
      browser.open = function()
        calls = calls + 1
        return true, nil, { job = 1 }
      end
      config.setup({ port = 0, auto_open_browser = true })

      session.open(make_markdown_buffer({ "# Hello" }))
      assert.equals(1, calls)
    end)

    it("does not spawn a second window when retargeting to a different buffer while a client is still connected", function()
      local calls = 0
      browser.open = function()
        calls = calls + 1
        return true, nil, { job = 1 }
      end
      config.setup({ port = 0, auto_open_browser = true })

      session.open(make_markdown_buffer({ "# One" }))
      assert.equals(1, calls)

      local client = connect_sse(session.port())
      vim.wait(1000, function()
        return server.client_count() == 1
      end, 10)

      session.open(make_markdown_buffer({ "# Two" }))
      assert.equals(1, calls) -- still 1: retargeted over SSE, no new window

      pcall(function()
        client:close()
      end)
    end)

    it("spawns a fresh window on reopen (same buffer) after the previous window disconnects", function()
      local calls = 0
      browser.open = function()
        calls = calls + 1
        return true, nil, { job = 1 }
      end
      config.setup({ port = 0, auto_open_browser = true })

      local bufnr = make_markdown_buffer({ "# Hello" })
      session.open(bufnr)
      assert.equals(1, calls)

      local client = connect_sse(session.port())
      vim.wait(1000, function()
        return server.client_count() == 1
      end, 10)
      pcall(function()
        client:close()
      end)
      vim.wait(1000, function()
        return server.client_count() == 0
      end, 10)

      session.open(bufnr) -- reopen the *same* buffer; the old window is gone
      assert.equals(2, calls)
    end)

    it("close() closes the tracked browser window handle", function()
      local closed_handle = nil
      browser.open = function()
        return true, nil, { job = 42 }
      end
      browser.close_app_window = function(handle)
        closed_handle = handle
      end
      config.setup({ port = 0, auto_open_browser = true })

      session.open(make_markdown_buffer({ "# Hello" }))
      session.close()

      assert.is_not_nil(closed_handle)
      assert.equals(42, closed_handle.job)
    end)
  end)
end)
