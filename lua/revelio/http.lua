-- Pure HTTP/1.1 request parser and response builder. No sockets — fully
-- unit-testable without a running server.
local M = {}

M.STATUS_TEXT = {
  [200] = "OK",
  [204] = "No Content",
  [400] = "Bad Request",
  [404] = "Not Found",
  [500] = "Internal Server Error",
}

local function url_decode(s)
  s = s:gsub("+", " ")
  s = s:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return s
end

local function parse_query(qs)
  local query = {}
  if not qs or qs == "" then
    return query
  end
  for pair in qs:gmatch("[^&]+") do
    local k, v = pair:match("^([^=]+)=?(.*)$")
    if k then
      query[url_decode(k)] = url_decode(v or "")
    end
  end
  return query
end

--- Parse a raw HTTP request buffer.
--- @param raw string
--- @return table|nil req
--- @return string|nil err "incomplete" (need more bytes) or "malformed"
function M.parse_request(raw)
  local header_end = raw:find("\r\n\r\n", 1, true)
  if not header_end then
    return nil, "incomplete"
  end

  local head = raw:sub(1, header_end - 1)
  local lines = vim.split(head, "\r\n")

  local request_line = lines[1] or ""
  local method, full_path, version = request_line:match("^(%u+)%s+(%S+)%s+(HTTP/%d%.%d)$")
  if not method or not full_path or not version then
    return nil, "malformed"
  end

  local path, qs = full_path:match("^([^?]*)%??(.*)$")
  local query = parse_query(qs)

  local headers = {}
  for i = 2, #lines do
    local key, value = lines[i]:match("^([^:]+):%s*(.*)$")
    if key then
      headers[key:lower()] = value
    end
  end

  local body_start = header_end + 4
  local content_length = tonumber(headers["content-length"])
  local body = ""

  if content_length and content_length > 0 then
    local available = #raw - body_start + 1
    if available < content_length then
      return nil, "incomplete"
    end
    body = raw:sub(body_start, body_start + content_length - 1)
  end

  return {
    method = method,
    path = path,
    query = query,
    headers = headers,
    body = body,
  }
end

--- Build a full HTTP/1.1 response.
--- @param status integer
--- @param headers table|nil
--- @param body string|nil
--- @return string
function M.response(status, headers, body)
  body = body or ""
  headers = vim.deepcopy(headers or {})
  local reason = M.STATUS_TEXT[status] or "Unknown"

  local has_content_type, has_content_length, has_connection = false, false, false
  for k in pairs(headers) do
    local lk = k:lower()
    if lk == "content-type" then
      has_content_type = true
    elseif lk == "content-length" then
      has_content_length = true
    elseif lk == "connection" then
      has_connection = true
    end
  end

  if not has_content_type then
    headers["Content-Type"] = "text/plain"
  end
  if not has_content_length then
    headers["Content-Length"] = tostring(#body)
  end
  if not has_connection then
    headers["Connection"] = "close"
  end

  local lines = { ("HTTP/1.1 %d %s"):format(status, reason) }
  for k, v in pairs(headers) do
    table.insert(lines, ("%s: %s"):format(k, v))
  end

  return table.concat(lines, "\r\n") .. "\r\n\r\n" .. body
end

--- SSE response preamble (headers only; connection stays open afterward).
--- @return string
function M.sse_headers()
  return table.concat({
    "HTTP/1.1 200 OK",
    "Content-Type: text/event-stream",
    "Cache-Control: no-cache",
    "Connection: keep-alive",
  }, "\r\n") .. "\r\n\r\n"
end

--- Format a single SSE event. data_tbl is JSON-encoded on one line.
--- @param event string
--- @param data_tbl table
--- @return string
function M.sse_event(event, data_tbl)
  local json = vim.json.encode(data_tbl)
  return ("event: %s\ndata: %s\n\n"):format(event, json)
end

return M
