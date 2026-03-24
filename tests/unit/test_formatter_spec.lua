local formatter = require("revelio.formatter")
local config = require("revelio.config")

describe("revelio.formatter", function()
  local cfg

  before_each(function()
    config.setup({})
    cfg = config.get()
  end)

  describe("get_log_spec()", function()
    it("returns spec for javascript buffers", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "javascript"
      local spec = formatter.get_log_spec(bufnr, cfg)
      assert.is_not_nil(spec)
      assert.equals("console.log", spec.fn)
      assert.is_true(spec.semicolon)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns spec for typescript buffers", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "typescript"
      local spec = formatter.get_log_spec(bufnr, cfg)
      assert.is_not_nil(spec)
      assert.equals("console.log", spec.fn)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns spec for python buffers", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "python"
      local spec = formatter.get_log_spec(bufnr, cfg)
      assert.is_not_nil(spec)
      assert.equals("print", spec.fn)
      assert.is_false(spec.semicolon)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns spec for lua buffers", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "lua"
      local spec = formatter.get_log_spec(bufnr, cfg)
      assert.is_not_nil(spec)
      assert.equals("print", spec.fn)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns spec for go buffers", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "go"
      local spec = formatter.get_log_spec(bufnr, cfg)
      assert.is_not_nil(spec)
      assert.equals("fmt.Println", spec.fn)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns nil for unsupported filetypes", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "rust"
      local spec = formatter.get_log_spec(bufnr, cfg)
      assert.is_nil(spec)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns nil for empty filetype", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = ""
      local spec = formatter.get_log_spec(bufnr, cfg)
      assert.is_nil(spec)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("build_log_line()", function()
    local js_spec = { fn = "console.log", semicolon = true }
    local py_spec = { fn = "print", semicolon = false }
    local go_spec = { fn = "fmt.Println", semicolon = false }

    it("builds basic JS log with all context", function()
      local line = formatter.build_log_line("myVar", {
        filename = "app.js",
        lnum = 42,
        fn_name = "myFunc",
        class_name = "MyClass",
      }, js_spec, cfg)
      assert.equals('console.log("🪄 ~ app.js:42 ~ MyClass ~ myFunc ~ myVar:", myVar);', line)
    end)

    it("builds JS log without class (default config)", function()
      local line = formatter.build_log_line("myVar", {
        filename = "app.js",
        fn_name = "myFunc",
      }, js_spec, cfg)
      assert.equals('console.log("🪄 ~ app.js ~ myFunc ~ myVar:", myVar);', line)
    end)

    it("builds JS log without filename", function()
      local line = formatter.build_log_line("myVar", {
        fn_name = "myFunc",
      }, js_spec, cfg)
      assert.equals('console.log("🪄 ~ myFunc ~ myVar:", myVar);', line)
    end)

    it("builds JS log with no context (only var)", function()
      local line = formatter.build_log_line("myVar", {}, js_spec, cfg)
      assert.equals('console.log("🪄 ~ myVar:", myVar);', line)
    end)

    it("adds semicolon for JS", function()
      local line = formatter.build_log_line("x", {}, js_spec, cfg)
      assert.is_not_nil(line:match(";$"))
    end)

    it("no semicolon for Python", function()
      local line = formatter.build_log_line("x", {}, py_spec, cfg)
      assert.is_nil(line:match(";$"))
      assert.is_not_nil(line:match("^print%("))
    end)

    it("no semicolon for Go", function()
      local line = formatter.build_log_line("x", {}, go_spec, cfg)
      assert.is_nil(line:match(";$"))
      assert.is_not_nil(line:match("^fmt%.Println%("))
    end)

    it("uses single-quote config", function()
      config.setup({ quote = "'" })
      cfg = config.get()
      local line = formatter.build_log_line("x", {}, js_spec, cfg)
      assert.is_not_nil(line:match("^console%.log%('"))
    end)

    it("uses backtick quote config", function()
      config.setup({ quote = "`" })
      cfg = config.get()
      local line = formatter.build_log_line("x", {}, js_spec, cfg)
      assert.is_not_nil(line:match("^console%.log%(`"))
    end)

    it("uses custom prefix", function()
      config.setup({ prefix = "LOG" })
      cfg = config.get()
      local line = formatter.build_log_line("x", {}, js_spec, cfg)
      assert.is_not_nil(line:match('"LOG '))
    end)

    it("uses custom delimiter", function()
      config.setup({ delimiter = "|" })
      cfg = config.get()
      local line = formatter.build_log_line("x", { fn_name = "fn" }, js_spec, cfg)
      assert.is_not_nil(line:match(" | "))
    end)

    it("includes filename without line number when lnum is nil", function()
      local line = formatter.build_log_line("v", { filename = "main.go" }, go_spec, cfg)
      assert.is_not_nil(line:match("main%.go ~"))
      assert.is_nil(line:match("main%.go:%d+"))
    end)

    it("includes filename with line number when lnum present", function()
      local line = formatter.build_log_line("v", { filename = "main.go", lnum = 10 }, go_spec, cfg)
      assert.is_not_nil(line:match("main%.go:10"))
    end)

    it("builds python log correctly", function()
      local line = formatter.build_log_line("data", {
        filename = "script.py",
        fn_name = "process",
      }, py_spec, cfg)
      assert.equals('print("🪄 ~ script.py ~ process ~ data:", data)', line)
    end)

    it("builds lua log correctly", function()
      local lua_spec = { fn = "print", semicolon = false }
      local line = formatter.build_log_line("tbl", { fn_name = "myFn" }, lua_spec, cfg)
      assert.equals('print("🪄 ~ myFn ~ tbl:", tbl)', line)
    end)
  end)
end)
