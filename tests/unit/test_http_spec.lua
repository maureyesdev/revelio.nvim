local http = require("revelio.http")

describe("revelio.http", function()
  describe("parse_request", function()
    it("parses a simple GET request with headers", function()
      local raw = "GET /foo HTTP/1.1\r\nHost: localhost\r\nUser-Agent: test\r\n\r\n"
      local req = http.parse_request(raw)
      assert.is_not_nil(req)
      assert.equals("GET", req.method)
      assert.equals("/foo", req.path)
      assert.equals("localhost", req.headers["host"])
      assert.equals("test", req.headers["user-agent"])
      assert.equals("", req.body)
    end)

    it("parses query strings", function()
      local raw = "GET /events?session=42&flag=1 HTTP/1.1\r\nHost: x\r\n\r\n"
      local req = http.parse_request(raw)
      assert.equals("/events", req.path)
      assert.equals("42", req.query.session)
      assert.equals("1", req.query.flag)
    end)

    it("parses a POST request with a Content-Length body", function()
      local body = '{"message":"boom"}'
      local raw = ("POST /api/error HTTP/1.1\r\nHost: x\r\nContent-Length: %d\r\n\r\n%s"):format(#body, body)
      local req = http.parse_request(raw)
      assert.equals("POST", req.method)
      assert.equals(body, req.body)
    end)

    it("returns nil, 'incomplete' when headers are not fully received", function()
      local raw = "GET /foo HTTP/1.1\r\nHost: loc"
      local req, err = http.parse_request(raw)
      assert.is_nil(req)
      assert.equals("incomplete", err)
    end)

    it("returns nil, 'incomplete' when body is shorter than Content-Length", function()
      local raw = "POST /x HTTP/1.1\r\nContent-Length: 10\r\n\r\nabc"
      local req, err = http.parse_request(raw)
      assert.is_nil(req)
      assert.equals("incomplete", err)
    end)

    it("returns nil, 'malformed' for a bad request line", function()
      local raw = "NOT A REQUEST LINE\r\n\r\n"
      local req, err = http.parse_request(raw)
      assert.is_nil(req)
      assert.equals("malformed", err)
    end)
  end)

  describe("response", function()
    it("builds a status line with the reason phrase", function()
      local resp = http.response(200, nil, "hi")
      assert.matches("^HTTP/1%.1 200 OK\r\n", resp)
    end)

    it("terminates headers with a blank CRLF line before the body", function()
      local resp = http.response(200, { ["Content-Type"] = "text/plain" }, "hi")
      assert.matches("\r\n\r\nhi$", resp)
    end)

    it("sets Content-Length automatically", function()
      local resp = http.response(200, nil, "hello")
      assert.matches("Content%-Length: 5\r\n", resp)
    end)

    it("uses the 404 Not Found reason phrase", function()
      local resp = http.response(404, nil, "")
      assert.matches("^HTTP/1%.1 404 Not Found\r\n", resp)
    end)

    it("defaults Connection to close", function()
      local resp = http.response(200, nil, "")
      assert.matches("Connection: close\r\n", resp)
    end)
  end)

  describe("sse_headers", function()
    it("returns an event-stream response preamble", function()
      local headers = http.sse_headers()
      assert.matches("^HTTP/1%.1 200 OK\r\n", headers)
      assert.matches("Content%-Type: text/event%-stream\r\n", headers)
      assert.matches("\r\n\r\n$", headers)
    end)
  end)

  describe("sse_event", function()
    it("formats a single-line JSON SSE event", function()
      local ev = http.sse_event("source", { rev = 1, ok = true })
      assert.matches("^event: source\n", ev)
      local data_line = ev:match("data: (.-)\n\n$")
      assert.is_not_nil(data_line)
      assert.is_nil(data_line:find("\n"))
    end)
  end)
end)
