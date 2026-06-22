local signs = require("dap-controls.signs")

describe("dap-controls.signs", function()
  before_each(function()
    -- Reset configured flag so each test starts fresh
    package.loaded["dap-controls.signs"] = nil
    signs = require("dap-controls.signs")
  end)

  it("setup() defines all five DAP signs", function()
    signs.setup()

    local expected = {
      "DapBreakpoint",
      "DapBreakpointCondition",
      "DapLogPoint",
      "DapStopped",
      "DapBreakpointRejected",
    }

    for _, name in ipairs(expected) do
      local defined = vim.fn.sign_getdefined(name)
      assert.is_true(#defined > 0, "sign not defined: " .. name)
    end
  end)

  it("setup() sets correct sign text", function()
    signs.setup()

    local check = {
      DapBreakpoint          = "●",
      DapBreakpointCondition = "◆",
      DapLogPoint            = "◉",
      DapStopped             = "▶",
      DapBreakpointRejected  = "○",
    }

    for name, expected_text in pairs(check) do
      local def = vim.fn.sign_getdefined(name)
      -- sign_getdefined may pad text with a trailing space; trim before comparing
      local actual = vim.trim(def[1].text)
      assert.equals(expected_text, actual, "wrong text for " .. name)
    end
  end)

  it("setup() is idempotent (safe to call multiple times)", function()
    signs.setup()
    signs.setup()
    signs.setup()

    local defined = vim.fn.sign_getdefined("DapBreakpoint")
    assert.equals(1, #defined)
  end)
end)
