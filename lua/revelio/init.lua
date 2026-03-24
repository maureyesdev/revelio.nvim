local M = {}

local config    = require("revelio.config")
local detector  = require("revelio.detector")
local formatter = require("revelio.formatter")
local inserter  = require("revelio.inserter")
local manager   = require("revelio.manager")

--- Set up the plugin with optional user configuration.
--- @param opts table|nil
function M.setup(opts)
  config.setup(opts)
  local cfg = config.get()

  if cfg.default_keymaps then
    local km = cfg.keymaps
    vim.keymap.set("n", km.log,       M.log,       { desc = "Revelio: insert log for variable" })
    vim.keymap.set("v", km.log,       M.log,       { desc = "Revelio: insert log for selection" })
    vim.keymap.set("n", km.delete,    M.delete,    { desc = "Revelio: delete all logs" })
    vim.keymap.set("n", km.comment,   M.comment,   { desc = "Revelio: comment all logs" })
    vim.keymap.set("n", km.uncomment, M.uncomment, { desc = "Revelio: uncomment all logs" })
    vim.keymap.set("n", km.correct,   M.correct,   { desc = "Revelio: correct all log metadata" })
  end
end

--- Insert a debug log line for the variable under cursor (or visual selection).
function M.log()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum  = vim.api.nvim_win_get_cursor(0)[1]  -- 1-indexed
  local mode  = vim.fn.mode()

  local var_name = detector.get_variable(mode)
  if not var_name or var_name == "" then
    vim.notify("revelio: no variable found under cursor", vim.log.levels.WARN)
    return
  end

  local cfg = config.get()
  local log_spec = formatter.get_log_spec(bufnr, cfg)
  if not log_spec then
    vim.notify("revelio: unsupported filetype — " .. vim.bo[bufnr].filetype, vim.log.levels.WARN)
    return
  end

  local ctx = {}
  if cfg.include_filename then
    ctx.filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    if ctx.filename == "" then ctx.filename = nil end
  end
  if cfg.include_line_number then
    ctx.lnum = lnum
  end
  if cfg.include_function then
    ctx.fn_name = detector.get_enclosing_function(bufnr, lnum)
  end
  if cfg.include_class then
    ctx.class_name = detector.get_enclosing_class(bufnr, lnum)
  end

  local indent    = inserter.get_indent(bufnr, lnum)
  local log_line  = formatter.build_log_line(var_name, ctx, log_spec, cfg)
  local insert_at = inserter.find_insert_point(bufnr, lnum)
  inserter.insert_log(bufnr, insert_at, indent, log_line)
end

--- Delete all revelio log lines in the current buffer.
function M.delete()
  manager.delete_logs(vim.api.nvim_get_current_buf(), config.get())
end

--- Comment all revelio log lines in the current buffer.
function M.comment()
  manager.comment_logs(vim.api.nvim_get_current_buf(), config.get())
end

--- Uncomment all revelio log lines in the current buffer.
function M.uncomment()
  manager.uncomment_logs(vim.api.nvim_get_current_buf(), config.get())
end

--- Correct filename:line metadata in all revelio log lines.
function M.correct()
  manager.correct_logs(vim.api.nvim_get_current_buf(), config.get())
end

return M
