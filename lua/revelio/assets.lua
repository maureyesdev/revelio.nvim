-- Locates and reads the static web assets served by revelio.server.
local M = {}

local function plugin_root()
  -- This file lives at <root>/lua/revelio/assets.lua — three :h hops
  -- (assets.lua's own file -> lua/revelio -> lua -> <root>).
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
end

local function read_file(rel_path)
  local path = plugin_root() .. "/assets/" .. rel_path
  local f, open_err = io.open(path, "rb")
  if not f then
    return nil, ("cannot open %s: %s"):format(path, open_err)
  end
  local content = f:read("*a")
  f:close()
  return content
end

--- @return string|nil content
--- @return string mime_type
function M.html()
  return read_file("index.html"), "text/html"
end

--- @return string|nil content
--- @return string mime_type
function M.js()
  return read_file("app.js"), "application/javascript"
end

--- @return string|nil content
--- @return string mime_type
function M.css()
  return read_file("app.css"), "text/css"
end

return M
