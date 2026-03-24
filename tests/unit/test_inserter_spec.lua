local inserter = require("revelio.inserter")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

describe("revelio.inserter", function()
  describe("get_indent()", function()
    it("returns empty string for non-indented line", function()
      local bufnr = make_buf({ "local x = 1" })
      assert.equals("", inserter.get_indent(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns spaces for indented line", function()
      local bufnr = make_buf({ "  local x = 1" })
      assert.equals("  ", inserter.get_indent(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns tabs for tab-indented line", function()
      local bufnr = make_buf({ "\t\tlocal x = 1" })
      assert.equals("\t\t", inserter.get_indent(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns empty string for empty line", function()
      local bufnr = make_buf({ "" })
      assert.equals("", inserter.get_indent(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("reads from the correct line number", function()
      local bufnr = make_buf({ "no_indent", "  indented" })
      assert.equals("", inserter.get_indent(bufnr, 1))
      assert.equals("  ", inserter.get_indent(bufnr, 2))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("find_insert_point()", function()
    it("returns same line when brackets already balanced", function()
      local bufnr = make_buf({ "const x = foo(a, b)", "next line" })
      assert.equals(1, inserter.find_insert_point(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("advances past multi-line function call", function()
      local bufnr = make_buf({
        "const x = foo(",
        "  a,",
        "  b",
        ")",
        "next line",
      })
      assert.equals(4, inserter.find_insert_point(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("handles single open bracket on one line", function()
      local bufnr = make_buf({ "const x = [", "  1, 2, 3", "]" })
      assert.equals(3, inserter.find_insert_point(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns lnum for already-balanced single line", function()
      local bufnr = make_buf({ "const x = obj.method()" })
      assert.equals(1, inserter.find_insert_point(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("caps scan at MAX_SCAN lines and returns lnum as fallback", function()
      -- 25 unclosed parens - exceeds MAX_SCAN of 20
      local lines = {}
      for i = 1, 25 do
        lines[i] = "  ("
      end
      local bufnr = make_buf(lines)
      local result = inserter.find_insert_point(bufnr, 1)
      -- Should return lnum (1) since never balanced within 20 lines
      assert.equals(1, result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("handles empty buffer (single line)", function()
      local bufnr = make_buf({ "x" })
      assert.equals(1, inserter.find_insert_point(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("handles nested brackets", function()
      local bufnr = make_buf({
        "foo([",
        "  {a: 1},",
        "])",
        "done",
      })
      assert.equals(3, inserter.find_insert_point(bufnr, 1))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("insert_log()", function()
    it("inserts line after insert_lnum", function()
      local bufnr = make_buf({ "const x = 1", "next" })
      inserter.insert_log(bufnr, 1, "", "console.log(x)")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("const x = 1", lines[1])
      assert.equals("console.log(x)", lines[2])
      assert.equals("next", lines[3])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("inserts with indentation", function()
      local bufnr = make_buf({ "  const x = 1" })
      inserter.insert_log(bufnr, 1, "  ", "console.log(x)")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("  console.log(x)", lines[2])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("appends when insert_lnum equals buffer length", function()
      local bufnr = make_buf({ "last line" })
      inserter.insert_log(bufnr, 1, "", "print(x)")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(2, #lines)
      assert.equals("print(x)", lines[2])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
