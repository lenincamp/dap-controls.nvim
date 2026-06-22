local keymaps

describe("dap-controls.keymaps", function()
  before_each(function()
    package.loaded["dap-controls.keymaps"] = nil
    keymaps = require("dap-controls.keymaps")
  end)

  -- ── lazy_keys ─────────────────────────────────────────────────────────────

  describe("lazy_keys()", function()
    it("returns a non-empty table", function()
      local keys = keymaps.lazy_keys()
      assert.is_true(#keys > 0)
    end)

    it("each entry has lhs, mode, desc", function()
      for _, k in ipairs(keymaps.lazy_keys()) do
        assert.truthy(k[1],    "missing lhs")
        assert.truthy(k.mode,  "missing mode")
        assert.truthy(k.desc,  "missing desc")
      end
    end)

    it("all lhs start with <leader>d", function()
      for _, k in ipairs(keymaps.lazy_keys()) do
        assert.is_true(
          vim.startswith(k[1], "<leader>d"),
          "unexpected lhs: " .. tostring(k[1])
        )
      end
    end)
  end)

  -- ── lazy_specs ────────────────────────────────────────────────────────────

  describe("lazy_specs()", function()
    it("returns same count as lazy_keys", function()
      assert.equals(#keymaps.lazy_keys(), #keymaps.lazy_specs())
    end)

    it("each spec has mode, lhs, desc", function()
      for _, s in ipairs(keymaps.lazy_specs()) do
        assert.truthy(s.mode, "missing mode")
        assert.truthy(s.lhs,  "missing lhs")
        assert.truthy(s.desc, "missing desc")
      end
    end)
  end)

  -- ── apply ─────────────────────────────────────────────────────────────────

  describe("apply()", function()
    it("does nothing when dap is not a table", function()
      assert.has_no_error(function() keymaps.apply(nil, {}) end)
    end)

    it("does nothing when helpers is not a table", function()
      assert.has_no_error(function() keymaps.apply({}, nil) end)
    end)

    it("registers keymaps without error given valid dap+helpers", function()
      local fake_dap     = { continue = function() end }
      local fake_helpers = { run_to_cursor = function() end }
      assert.has_no_error(function()
        keymaps.apply(fake_dap, fake_helpers)
      end)
    end)

    it("registers <leader>dc in normal mode", function()
      local fake_dap     = { continue = function() end }
      local fake_helpers = {}
      keymaps.apply(fake_dap, fake_helpers)

      local map = vim.fn.maparg("<leader>dc", "n", false, true)
      assert.truthy(map and map.desc)
      assert.equals("Debug: Continue", map.desc)
    end)
  end)
end)
