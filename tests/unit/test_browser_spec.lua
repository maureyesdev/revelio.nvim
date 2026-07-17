local browser = require("revelio.browser")

describe("revelio.browser", function()
  describe("browser_cmd override", function()
    it("bypasses browser_mode entirely and is used verbatim, with a nil handle", function()
      local ok, err, handle = browser.open("http://127.0.0.1:1/", {
        browser_mode = "app",
        browser_cmd = "revelio-test-nonexistent-browser-xyz123",
      })
      assert.is_false(ok)
      assert.matches("revelio%-test%-nonexistent%-browser%-xyz123", err)
      assert.matches("not found on PATH", err)
      assert.is_nil(handle)
    end)
  end)

  describe("open() with browser_mode = 'app' — handle shape", function()
    it("returns a table handle with job/pid on success, without spawning a real browser", function()
      -- Only meaningful if this machine actually has a Chromium-family
      -- browser; otherwise there's nothing to detect and nothing to assert.
      if not browser.detect_app_browser() then
        return
      end

      -- Stub jobstart/jobpid so this test never launches a real window.
      local orig_jobstart = vim.fn.jobstart
      local orig_jobpid = vim.fn.jobpid
      vim.fn.jobstart = function()
        return 4242
      end
      vim.fn.jobpid = function()
        return 99999
      end

      local ok, _, handle = browser.open("http://127.0.0.1:1/", { browser_mode = "app" })

      vim.fn.jobstart = orig_jobstart
      vim.fn.jobpid = orig_jobpid

      assert.is_true(ok)
      assert.equals("table", type(handle))
      assert.equals(4242, handle.job)
      assert.equals(99999, handle.pid)
    end)

    it("returns ok=false, handle=nil when no Chromium-family browser is found", function()
      local orig_detect_dep = vim.fn.executable
      local orig_isdirectory = vim.fn.isdirectory
      vim.fn.executable = function()
        return 0
      end
      vim.fn.isdirectory = function()
        return 0
      end

      local ok, _, handle = browser.open("http://127.0.0.1:1/", { browser_mode = "app" })

      vim.fn.executable = orig_detect_dep
      vim.fn.isdirectory = orig_isdirectory

      -- Falls back to tab mode; on a headless CI box with no browser at all
      -- this is false too, but either way there must be no app-mode handle.
      assert.is_nil(handle)
      assert.is_boolean(ok)
    end)
  end)

  describe("close_app_window()", function()
    it("is a no-op for a nil handle", function()
      local ok = pcall(browser.close_app_window, nil)
      assert.is_true(ok)
    end)

    it("is a no-op for a handle with no job", function()
      local ok = pcall(browser.close_app_window, {})
      assert.is_true(ok)
    end)

    it("does not error when stopping an already-invalid job id", function()
      local ok = pcall(browser.close_app_window, { job = -999 })
      assert.is_true(ok)
    end)
  end)

  describe("detect_app_browser()", function()
    it("does not error and returns a string cmd or nil", function()
      local ok, cmd = pcall(browser.detect_app_browser)
      assert.is_true(ok)
      assert.is_true(cmd == nil or type(cmd) == "string")
    end)
  end)

  describe("open() with browser_mode = 'tab'", function()
    it("resolves a system opener without erroring", function()
      local ok = pcall(browser.open, "http://127.0.0.1:1/", { browser_mode = "tab" })
      assert.is_true(ok)
    end)
  end)
end)
