local debounce = require("revelio.debounce")

describe("revelio.debounce", function()
  before_each(function()
    debounce.cancel_all()
  end)

  after_each(function()
    debounce.cancel_all()
  end)

  it("calls fn after delay", function()
    local called = false
    debounce.debounce("test_key", 10, function()
      called = true
    end)
    -- Timer should not have fired yet
    assert.is_false(called)
    -- Wait for it to fire (poll with vim.wait)
    vim.wait(100, function()
      return called
    end, 5)
    assert.is_true(called)
  end)

  it("cancels previous timer when called again with same key", function()
    local call_count = 0
    debounce.debounce("same_key", 30, function()
      call_count = call_count + 1
    end)
    debounce.debounce("same_key", 30, function()
      call_count = call_count + 1
    end)
    vim.wait(100, function()
      return call_count > 0
    end, 5)
    -- Only the second timer should fire
    assert.equals(1, call_count)
  end)

  it("different keys are independent", function()
    local a_called = false
    local b_called = false
    debounce.debounce("key_a", 10, function()
      a_called = true
    end)
    debounce.debounce("key_b", 10, function()
      b_called = true
    end)
    vim.wait(100, function()
      return a_called and b_called
    end, 5)
    assert.is_true(a_called)
    assert.is_true(b_called)
  end)

  it("cancel() prevents fn from firing", function()
    local called = false
    debounce.debounce("cancel_key", 50, function()
      called = true
    end)
    debounce.cancel("cancel_key")
    vim.wait(100, function()
      return called
    end, 5)
    assert.is_false(called)
  end)

  it("cancel_all() stops all pending timers", function()
    local count = 0
    debounce.debounce("k1", 50, function()
      count = count + 1
    end)
    debounce.debounce("k2", 50, function()
      count = count + 1
    end)
    debounce.cancel_all()
    vim.wait(100, function()
      return count > 0
    end, 5)
    assert.equals(0, count)
  end)
end)
