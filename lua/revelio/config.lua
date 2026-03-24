local M = {}

local DEFAULTS = {
  prefix = "🚀",
  delimiter = "~",
  quote = '"',
  include_filename = true,
  include_line_number = false,
  include_function = true,
  include_class = false,
  log_functions = {
    javascript      = { fn = "console.log", semicolon = true },
    typescript      = { fn = "console.log", semicolon = true },
    javascriptreact = { fn = "console.log", semicolon = true },
    typescriptreact = { fn = "console.log", semicolon = true },
    python          = { fn = "print",       semicolon = false },
    lua             = { fn = "print",       semicolon = false },
    go              = { fn = "fmt.Println", semicolon = false },
  },
  keymaps = {
    log       = "<leader>rl",
    delete    = "<leader>rd",
    comment   = "<leader>rc",
    uncomment = "<leader>ru",
    correct   = "<leader>rx",
  },
  default_keymaps = true,
}

local _cfg = vim.deepcopy(DEFAULTS)

function M.setup(opts)
  _cfg = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})
end

function M.get()
  return _cfg
end

function M.defaults()
  return vim.deepcopy(DEFAULTS)
end

return M
