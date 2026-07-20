local config = require("revelio.config")

describe("revelio.config", function()
  before_each(function()
    config.setup({})
  end)

  describe("defaults", function()
    it("has host = '127.0.0.1'", function()
      assert.equals("127.0.0.1", config.get().host)
    end)

    it("has port = 0", function()
      assert.equals(0, config.get().port)
    end)

    it("has auto_open_browser = true", function()
      assert.is_true(config.get().auto_open_browser)
    end)

    it("has browser_mode = 'app'", function()
      assert.equals("app", config.get().browser_mode)
    end)

    it("has browser_cmd = nil", function()
      assert.is_nil(config.get().browser_cmd)
    end)

    it("has theme = 'auto'", function()
      assert.equals("auto", config.get().theme)
    end)

    it("has debounce_ms = 250", function()
      assert.equals(250, config.get().debounce_ms)
    end)

    it("has follow_cursor = true", function()
      assert.is_true(config.get().follow_cursor)
    end)

    it("has filetypes including markdown and markdown.mdx", function()
      local ft = config.get().filetypes
      assert.is_true(vim.tbl_contains(ft, "markdown"))
      assert.is_true(vim.tbl_contains(ft, "markdown.mdx"))
    end)

    it("has mermaid_fences = 'plain'", function()
      assert.equals("plain", config.get().mermaid_fences)
    end)

    it("has cdn.markdown_it pointing at markdown-it v14", function()
      assert.matches("markdown%-it@14", config.get().cdn.markdown_it)
    end)

    it("has cdn.mermaid_js pointing at mermaid v11", function()
      assert.matches("mermaid@11", config.get().cdn.mermaid_js)
    end)

    it("has export.dir = nil", function()
      assert.is_nil(config.get().export.dir)
    end)

    it("has default_keymaps = true", function()
      assert.is_true(config.get().default_keymaps)
    end)

    it("has keymaps.preview = '<leader>vp'", function()
      assert.equals("<leader>vp", config.get().keymaps.preview)
    end)
  end)

  describe("mermaid_fences validation", function()
    it("accepts 'render' unchanged", function()
      config.setup({ mermaid_fences = "render" })
      assert.equals("render", config.get().mermaid_fences)
    end)

    it("falls back to 'plain' and warns on an unknown value", function()
      config.setup({ mermaid_fences = "bogus" })
      assert.equals("plain", config.get().mermaid_fences)
    end)
  end)

  describe("setup merging", function()
    it("overrides only the keys provided", function()
      config.setup({ host = "0.0.0.0" })
      assert.equals("0.0.0.0", config.get().host)
      assert.equals(0, config.get().port)
    end)
  end)

  describe("defaults()", function()
    it("returns a fresh copy independent of setup() state", function()
      local d = config.defaults()
      config.setup({ host = "0.0.0.0" })
      assert.equals("127.0.0.1", d.host)
    end)
  end)
end)
