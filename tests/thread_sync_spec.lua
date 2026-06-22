local ts

describe("dap-controls.thread_sync", function()
  before_each(function()
    package.loaded["dap-controls.thread_sync"] = nil
    vim.g.nvim_pure_dap_thread_sync = nil
    ts = require("dap-controls.thread_sync")
  end)

  -- ── _find_any_stopped_thread ──────────────────────────────────────────────

  describe("_find_any_stopped_thread", function()
    it("returns nil for nil session", function()
      assert.is_nil(ts._find_any_stopped_thread(nil))
    end)

    it("returns nil when no thread is stopped", function()
      local session = { threads = { [1] = { stopped = false }, [2] = { stopped = false } } }
      assert.is_nil(ts._find_any_stopped_thread(session))
    end)

    it("returns tid of first stopped thread", function()
      local session = {
        threads = {
          [10] = { stopped = false },
          [20] = { stopped = true  },
        },
      }
      local tid = ts._find_any_stopped_thread(session)
      assert.equals(20, tid)
    end)
  end)

  -- ── _find_thread_for_frame ────────────────────────────────────────────────

  describe("_find_thread_for_frame", function()
    it("returns nil for nil session", function()
      assert.is_nil(ts._find_thread_for_frame(nil, 1))
    end)

    it("returns nil when frame not found", function()
      local session = {
        threads = {
          [1] = { id = 1, frames = { { id = 10 } } },
        },
      }
      assert.is_nil(ts._find_thread_for_frame(session, 99))
    end)

    it("returns correct tid when frame found", function()
      -- threads must have an `id` field matching the DAP thread ID
      local session = {
        threads = {
          [1] = { id = 1, frames = { { id = 10 }, { id = 11 } } },
          [2] = { id = 2, frames = { { id = 20 } } },
        },
      }
      assert.equals(1, ts._find_thread_for_frame(session, 10))
      assert.equals(2, ts._find_thread_for_frame(session, 20))
    end)
  end)

  -- ── _recover_stopped_thread_id ────────────────────────────────────────────

  describe("_recover_stopped_thread_id", function()
    it("does nothing for nil session", function()
      assert.has_no_error(function() ts._recover_stopped_thread_id(nil) end)
    end)

    it("does nothing when stopped_thread_id is already set", function()
      local session = { stopped_thread_id = 5, threads = {} }
      ts._recover_stopped_thread_id(session)
      assert.equals(5, session.stopped_thread_id)
    end)

    it("sets stopped_thread_id from stopped thread", function()
      local session = {
        stopped_thread_id = nil,
        threads = {
          [1] = { stopped = false, frames = {} },
          [2] = { stopped = true,  frames = {} },
        },
      }
      ts._recover_stopped_thread_id(session)
      assert.equals(2, session.stopped_thread_id)
    end)

    it("falls back to thread with frames when none stopped", function()
      local session = {
        stopped_thread_id = nil,
        current_frame     = nil,
        threads = {
          [3] = { stopped = false, frames = { { id = 30 } } },
        },
      }
      ts._recover_stopped_thread_id(session)
      assert.equals(3, session.stopped_thread_id)
    end)
  end)

  -- ── apply ────────────────────────────────────────────────────────────────

  describe("apply()", function()
    it("sets nvim_pure_dap_thread_sync guard flag", function()
      ts.apply()
      assert.is_true(vim.g.nvim_pure_dap_thread_sync == true)
    end)

    it("is idempotent (second call is a no-op)", function()
      ts.apply()
      ts.apply()
      assert.is_true(vim.g.nvim_pure_dap_thread_sync == true)
    end)

    it("patches Session._frame_set to sync stopped_thread_id", function()
      ts.apply()

      local Session = package.loaded["dap.session"]
      -- thread must carry `id` field — DAP thread objects have an `id` property
      local fake_session = {
        stopped_thread_id = nil,
        current_frame     = nil,
        threads           = { [7] = { id = 7, frames = { { id = 99 } } } },
      }

      Session._frame_set(fake_session, { id = 99 })
      assert.equals(7, fake_session.stopped_thread_id)
    end)
  end)
end)
