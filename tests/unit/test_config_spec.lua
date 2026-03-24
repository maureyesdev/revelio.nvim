local config = require("revelio.config")

describe("revelio.config", function()
  before_each(function()
    config.setup({})
  end)

  describe("defaults", function()
    it("has correct prefix", function()
      assert.equals("🚀", config.defaults().prefix)
    end)

    it("has correct delimiter", function()
      assert.equals("~", config.defaults().delimiter)
    end)

    it("has double-quote as default", function()
      assert.equals('"', config.defaults().quote)
    end)

    it("includes filename by default", function()
      assert.is_true(config.defaults().include_filename)
    end)

    it("excludes line number by default", function()
      assert.is_false(config.defaults().include_line_number)
    end)

    it("includes function by default", function()
      assert.is_true(config.defaults().include_function)
    end)

    it("excludes class by default", function()
      assert.is_false(config.defaults().include_class)
    end)

    it("enables default_keymaps by default", function()
      assert.is_true(config.defaults().default_keymaps)
    end)
  end)

  describe("log_functions defaults", function()
    it("javascript uses console.log with semicolon", function()
      local js = config.defaults().log_functions.javascript
      assert.equals("console.log", js.fn)
      assert.is_true(js.semicolon)
    end)

    it("typescript uses console.log with semicolon", function()
      local ts = config.defaults().log_functions.typescript
      assert.equals("console.log", ts.fn)
      assert.is_true(ts.semicolon)
    end)

    it("javascriptreact uses console.log with semicolon", function()
      local jsx = config.defaults().log_functions.javascriptreact
      assert.equals("console.log", jsx.fn)
      assert.is_true(jsx.semicolon)
    end)

    it("typescriptreact uses console.log with semicolon", function()
      local tsx = config.defaults().log_functions.typescriptreact
      assert.equals("console.log", tsx.fn)
      assert.is_true(tsx.semicolon)
    end)

    it("python uses print without semicolon", function()
      local py = config.defaults().log_functions.python
      assert.equals("print", py.fn)
      assert.is_false(py.semicolon)
    end)

    it("lua uses print without semicolon", function()
      local lua = config.defaults().log_functions.lua
      assert.equals("print", lua.fn)
      assert.is_false(lua.semicolon)
    end)

    it("go uses fmt.Println without semicolon", function()
      local go = config.defaults().log_functions.go
      assert.equals("fmt.Println", go.fn)
      assert.is_false(go.semicolon)
    end)
  end)

  describe("keymaps defaults", function()
    it("log keymap is <leader>rl", function()
      assert.equals("<leader>rl", config.defaults().keymaps.log)
    end)

    it("delete keymap is <leader>rd", function()
      assert.equals("<leader>rd", config.defaults().keymaps.delete)
    end)

    it("comment keymap is <leader>rc", function()
      assert.equals("<leader>rc", config.defaults().keymaps.comment)
    end)

    it("uncomment keymap is <leader>ru", function()
      assert.equals("<leader>ru", config.defaults().keymaps.uncomment)
    end)

    it("correct keymap is <leader>rx", function()
      assert.equals("<leader>rx", config.defaults().keymaps.correct)
    end)
  end)

  describe("setup()", function()
    it("merges user options over defaults", function()
      config.setup({ prefix = "LOG", quote = "'" })
      local cfg = config.get()
      assert.equals("LOG", cfg.prefix)
      assert.equals("'", cfg.quote)
    end)

    it("preserves defaults for unset keys", function()
      config.setup({ prefix = "X" })
      local cfg = config.get()
      assert.equals("~", cfg.delimiter)
      assert.is_true(cfg.include_filename)
    end)

    it("deep-merges nested keymaps", function()
      config.setup({ keymaps = { log = "<leader>ll" } })
      local cfg = config.get()
      assert.equals("<leader>ll", cfg.keymaps.log)
      assert.equals("<leader>rd", cfg.keymaps.delete)
    end)

    it("deep-merges nested log_functions", function()
      config.setup({ log_functions = { python = { fn = "logging.debug", semicolon = false } } })
      local cfg = config.get()
      assert.equals("logging.debug", cfg.log_functions.python.fn)
      assert.equals("console.log", cfg.log_functions.javascript.fn)
    end)

    it("does not mutate DEFAULTS", function()
      config.setup({ prefix = "CHANGED" })
      assert.equals("🚀", config.defaults().prefix)
    end)

    it("resets to defaults when called with empty opts", function()
      config.setup({ prefix = "X" })
      config.setup({})
      assert.equals("🚀", config.get().prefix)
    end)
  end)
end)
