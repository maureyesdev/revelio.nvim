local watcher = require("revelio.watcher")
local config = require("revelio.config")

local function make_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# Title", "body" })
  return bufnr
end

-- TextChanged only fires on Neovim's own normal-mode "did anything change"
-- tick (cursor move, mode transition, etc.) — a plain nvim_buf_set_lines()
-- call in a headless script doesn't trigger it. Fire it explicitly to
-- simulate what real typing does.
local function edit(bufnr, line)
  vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { line })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })
end

describe("revelio.watcher", function()
  before_each(function()
    config.setup({ debounce_ms = 10 })
  end)

  it("calls on_change (debounced) after the buffer changes", function()
    local bufnr = make_buffer()
    local calls = 0
    watcher.attach(bufnr, function()
      calls = calls + 1
    end)

    edit(bufnr, "changed")

    vim.wait(200, function()
      return calls > 0
    end, 5)
    assert.equals(1, calls)

    watcher.detach(bufnr)
  end)

  it("debounces a burst of edits into a single call", function()
    local bufnr = make_buffer()
    local calls = 0
    watcher.attach(bufnr, function()
      calls = calls + 1
    end)

    for i = 1, 5 do
      edit(bufnr, "line " .. i)
    end

    vim.wait(200, function()
      return calls > 0
    end, 5)
    -- give any (incorrect) extra debounce fires a chance to happen too
    vim.wait(50)
    assert.equals(1, calls)

    watcher.detach(bufnr)
  end)

  it("detach() stops further calls", function()
    local bufnr = make_buffer()
    local calls = 0
    watcher.attach(bufnr, function()
      calls = calls + 1
    end)
    watcher.detach(bufnr)

    edit(bufnr, "after detach")
    vim.wait(100)
    assert.equals(0, calls)
  end)

  it("is_attached() reflects watcher state", function()
    local bufnr = make_buffer()
    assert.is_false(watcher.is_attached(bufnr))
    watcher.attach(bufnr, function() end)
    assert.is_true(watcher.is_attached(bufnr))
    watcher.detach(bufnr)
    assert.is_false(watcher.is_attached(bufnr))
  end)

  it("attach() is idempotent for an already-attached buffer", function()
    local bufnr = make_buffer()
    local calls = 0
    watcher.attach(bufnr, function()
      calls = calls + 1
    end)
    -- second attach with a different callback should be ignored
    watcher.attach(bufnr, function()
      calls = calls + 100
    end)

    edit(bufnr, "changed again")
    vim.wait(200, function()
      return calls > 0
    end, 5)
    assert.equals(1, calls)

    watcher.detach(bufnr)
  end)
end)
