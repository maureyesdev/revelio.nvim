local manager = require("revelio.manager")
local config = require("revelio.config")

local function make_buf(lines, filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  if filetype then
    vim.bo[bufnr].filetype = filetype
  end
  return bufnr
end

describe("revelio.manager", function()
  local cfg

  before_each(function()
    config.setup({})
    cfg = config.get()
  end)

  describe("find_revelio_lines()", function()
    it("returns empty list for buffer with no revelio lines", function()
      local bufnr = make_buf({ "const x = 1", "console.log(x)" })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(0, #result)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("finds lines containing the prefix", function()
      local bufnr = make_buf({
        "const x = 1",
        'console.log("🚀 ~ app.js ~ myFunc ~ x:", x);',
        "const y = 2",
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(1, #result)
      assert.equals(2, result[1].lnum)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("finds multiple revelio lines", function()
      local bufnr = make_buf({
        'console.log("🚀 ~ x:", x);',
        "const y = 2",
        'console.log("🚀 ~ y:", y);',
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(2, #result)
      assert.equals(1, result[1].lnum)
      assert.equals(3, result[2].lnum)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("marks JS-commented lines as commented", function()
      local bufnr = make_buf({
        '// console.log("🚀 ~ x:", x);',
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(1, #result)
      assert.is_true(result[1].commented)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("marks Python-commented lines as commented", function()
      local bufnr = make_buf({
        '# print("🚀 ~ x:", x)',
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(1, #result)
      assert.is_true(result[1].commented)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("marks Lua-commented lines as commented", function()
      local bufnr = make_buf({
        '-- print("🚀 ~ x:", x)',
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(1, #result)
      assert.is_true(result[1].commented)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("marks active (non-commented) lines correctly", function()
      local bufnr = make_buf({
        'console.log("🚀 ~ x:", x);',
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(1, #result)
      assert.is_false(result[1].commented)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("detects commented lines with leading whitespace", function()
      local bufnr = make_buf({
        '  // console.log("🚀 ~ x:", x);',
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(1, #result)
      assert.is_true(result[1].commented)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("respects custom prefix from config", function()
      config.setup({ prefix = "DBG" })
      cfg = config.get()
      local bufnr = make_buf({
        'console.log("DBG ~ x:", x);',
        'console.log("🚀 ~ y:", y);',
      })
      local result = manager.find_revelio_lines(bufnr, cfg)
      assert.equals(1, #result)
      assert.equals(1, result[1].lnum)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("delete_logs()", function()
    it("removes revelio lines from buffer", function()
      local bufnr = make_buf({
        "const x = 1",
        'console.log("🚀 ~ x:", x);',
        "const y = 2",
      })
      manager.delete_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(2, #lines)
      assert.equals("const x = 1", lines[1])
      assert.equals("const y = 2", lines[2])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("removes multiple revelio lines in correct order", function()
      local bufnr = make_buf({
        'console.log("🚀 ~ a:", a);',
        "const b = 2",
        'console.log("🚀 ~ b:", b);',
      })
      manager.delete_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("const b = 2", lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("also deletes commented revelio lines", function()
      local bufnr = make_buf({
        '// console.log("🚀 ~ x:", x);',
        "const y = 2",
      })
      manager.delete_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(1, #lines)
      assert.equals("const y = 2", lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("is a no-op on buffer with no revelio lines", function()
      local bufnr = make_buf({ "const x = 1" })
      manager.delete_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(1, #lines)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("comment_logs()", function()
    it("comments JS revelio lines with //", function()
      local bufnr = make_buf({
        'console.log("🚀 ~ x:", x);',
      }, "javascript")
      manager.comment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('// console.log("🚀 ~ x:", x);', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("comments Python revelio lines with #", function()
      local bufnr = make_buf({
        'print("🚀 ~ x:", x)',
      }, "python")
      manager.comment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('# print("🚀 ~ x:", x)', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("comments Lua revelio lines with --", function()
      local bufnr = make_buf({
        'print("🚀 ~ x:", x)',
      }, "lua")
      manager.comment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('-- print("🚀 ~ x:", x)', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("comments Go revelio lines with //", function()
      local bufnr = make_buf({
        'fmt.Println("🚀 ~ x:", x)',
      }, "go")
      manager.comment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('// fmt.Println("🚀 ~ x:", x)', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("preserves indentation when commenting", function()
      local bufnr = make_buf({
        '  console.log("🚀 ~ x:", x);',
      }, "javascript")
      manager.comment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('  // console.log("🚀 ~ x:", x);', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("does not double-comment already-commented lines", function()
      local bufnr = make_buf({
        '// console.log("🚀 ~ x:", x);',
      }, "javascript")
      manager.comment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('// console.log("🚀 ~ x:", x);', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("uncomment_logs()", function()
    it("removes // comment from JS revelio lines", function()
      local bufnr = make_buf({
        '// console.log("🚀 ~ x:", x);',
      }, "javascript")
      manager.uncomment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('console.log("🚀 ~ x:", x);', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("removes # comment from Python revelio lines", function()
      local bufnr = make_buf({
        '# print("🚀 ~ x:", x)',
      }, "python")
      manager.uncomment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('print("🚀 ~ x:", x)', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("removes -- comment from Lua revelio lines", function()
      local bufnr = make_buf({
        '-- print("🚀 ~ x:", x)',
      }, "lua")
      manager.uncomment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('print("🚀 ~ x:", x)', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("preserves indentation when uncommenting", function()
      local bufnr = make_buf({
        '  // console.log("🚀 ~ x:", x);',
      }, "javascript")
      manager.uncomment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('  console.log("🚀 ~ x:", x);', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("does not modify non-commented revelio lines", function()
      local bufnr = make_buf({
        'console.log("🚀 ~ x:", x);',
      }, "javascript")
      manager.uncomment_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('console.log("🚀 ~ x:", x);', lines[1])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("correct_logs()", function()
    it("updates filename:line in revelio log lines", function()
      -- Line 1 is the var, line 2 is the log -> expects filename:1
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, "/project/app.js")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const myVar = 1",
        'console.log("🚀 ~ app.js:99 ~ myVar:", myVar);',
      })
      manager.correct_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Line 2 should now show app.js:1
      assert.is_not_nil(lines[2]:match("app%.js:1"))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("does not modify lines without filename:line pattern", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, "/project/app.js")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "const x = 1",
        'console.log("🚀 ~ myFunc ~ x:", x);',
      })
      manager.correct_logs(bufnr, cfg)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals('console.log("🚀 ~ myFunc ~ x:", x);', lines[2])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
