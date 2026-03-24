local M = {}

--- Returns the log spec for the buffer's filetype, or nil if unsupported.
--- @param bufnr integer
--- @param cfg table
--- @return table|nil { fn: string, semicolon: boolean }
function M.get_log_spec(bufnr, cfg)
  local ft = vim.bo[bufnr].filetype
  return cfg.log_functions[ft]
end

--- Builds the full log line string (no leading indent).
--- @param var_name string
--- @param ctx table { filename?, lnum?, fn_name?, class_name? }
--- @param log_spec table { fn: string, semicolon: boolean }
--- @param cfg table
--- @return string
function M.build_log_line(var_name, ctx, log_spec, cfg)
  local q = cfg.quote
  local d = " " .. cfg.delimiter .. " "

  -- Build message parts
  local parts = { cfg.prefix }

  if ctx.filename then
    local file_part = ctx.filename
    if ctx.lnum then
      file_part = file_part .. ":" .. tostring(ctx.lnum)
    end
    parts[#parts + 1] = file_part
  end

  if ctx.class_name then
    parts[#parts + 1] = ctx.class_name
  end

  if ctx.fn_name then
    parts[#parts + 1] = ctx.fn_name
  end

  parts[#parts + 1] = var_name .. ":"

  local message = table.concat(parts, d)

  -- Build the log call
  local call = log_spec.fn .. "(" .. q .. message .. q .. ", " .. var_name .. ")"

  if log_spec.semicolon then
    call = call .. ";"
  end

  return call
end

return M
