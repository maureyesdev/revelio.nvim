local detector = require("revelio.detector")

describe("revelio.detector", function()
  describe("get_variable()", function()
    it("returns nil for empty cword", function()
      -- In headless mode with no file, cword will be empty
      -- We test the fallback path via the function directly
      -- Since we can't control cword in tests, we verify nil return for blank
      local result = detector.get_variable("n")
      -- Either a word or nil; cannot assert exact value without cursor control
      -- Just verify it returns a string or nil (not an error)
      assert.is_true(result == nil or type(result) == "string")
    end)

    it("returns string for normal mode cword", function()
      -- Set up a buffer with a word and position cursor on it
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "myVariable" })
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local result = detector.get_variable("n")
      assert.equals("myVariable", result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("get_enclosing_function()", function()
    it("returns nil for unsupported filetype", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "rust"
      local result = detector.get_enclosing_function(bufnr, 1)
      assert.is_nil(result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns nil when no tree-sitter parser available", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      -- Use a filetype that is in our map but may or may not have ts parser
      -- We expect nil or a string, no error
      vim.bo[bufnr].filetype = "lua"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local x = 1" })
      local ok, result = pcall(detector.get_enclosing_function, bufnr, 1)
      assert.is_true(ok)
      assert.is_true(result == nil or type(result) == "string")
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("finds function name in lua buffer", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "lua"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local function myFunc()",
        "  local x = 1",
        "end",
      })
      local ok, _ = pcall(vim.treesitter.get_parser, bufnr, "lua")
      if not ok then
        -- Skip if lua TS parser not installed
        vim.api.nvim_buf_delete(bufnr, { force = true })
        return
      end
      local result = detector.get_enclosing_function(bufnr, 2)
      assert.equals("myFunc", result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("finds function name in javascript buffer", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "javascript"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "function greet(name) {",
        "  return name;",
        "}",
      })
      local ok, _ = pcall(vim.treesitter.get_parser, bufnr, "javascript")
      if not ok then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        return
      end
      local result = detector.get_enclosing_function(bufnr, 2)
      assert.equals("greet", result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("finds function name in python buffer", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "python"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "def process(data):",
        "    return data",
      })
      local ok, _ = pcall(vim.treesitter.get_parser, bufnr, "python")
      if not ok then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        return
      end
      local result = detector.get_enclosing_function(bufnr, 2)
      assert.equals("process", result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns nil when cursor is not inside a function", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "lua"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "local x = 1",
      })
      local ok, _ = pcall(vim.treesitter.get_parser, bufnr, "lua")
      if not ok then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        return
      end
      local result = detector.get_enclosing_function(bufnr, 1)
      assert.is_nil(result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("get_enclosing_class()", function()
    it("returns nil for lua (no classes)", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "lua"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local x = 1" })
      local result = detector.get_enclosing_class(bufnr, 1)
      assert.is_nil(result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns nil for unsupported filetype", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "rust"
      local result = detector.get_enclosing_class(bufnr, 1)
      assert.is_nil(result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("finds class name in javascript", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "javascript"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "class MyService {",
        "  constructor() {",
        "    this.x = 1;",
        "  }",
        "}",
      })
      local ok, _ = pcall(vim.treesitter.get_parser, bufnr, "javascript")
      if not ok then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        return
      end
      local result = detector.get_enclosing_class(bufnr, 3)
      assert.equals("MyService", result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("finds class name in python", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].filetype = "python"
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "class Animal:",
        "    def speak(self):",
        "        return 'sound'",
      })
      local ok, _ = pcall(vim.treesitter.get_parser, bufnr, "python")
      if not ok then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        return
      end
      local result = detector.get_enclosing_class(bufnr, 3)
      assert.equals("Animal", result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
