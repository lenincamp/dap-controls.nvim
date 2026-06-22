local helpers

describe("dap-controls.helpers", function()
  before_each(function()
    package.loaded["dap-controls.helpers"] = nil
    _G._test_bp_calls         = {}
    _G._test_dap_view_calls   = {}
    _G._test_picker_calls     = {}
    _G._test_dap_session_active = nil
    _G._test_toggle_reset()
    helpers = require("dap-controls.helpers")
  end)

  -- ── _flatten_expr ──────────────────────────────────────────────────────────

  describe("_flatten_expr", function()
    it("returns empty string for nil input", function()
      assert.equals("", helpers._flatten_expr(nil))
    end)

    it("returns empty string for empty input", function()
      assert.equals("", helpers._flatten_expr(""))
    end)

    it("collapses whitespace", function()
      assert.equals("a b c", helpers._flatten_expr("a  b  c"))
    end)

    it("strips single-line comments", function()
      assert.equals("int x = 1;", helpers._flatten_expr("int x = 1; // comment"))
    end)

    it("joins multiline into single line", function()
      local result = helpers._flatten_expr("a\nb\nc")
      assert.equals("a b c", result)
    end)

    it("strips comments from each line before joining", function()
      local result = helpers._flatten_expr("int x = 1; // set x\nint y = 2;")
      -- spaces are collapsed after join, so trailing space from comment strip becomes single space
      assert.equals("int x = 1; int y = 2;", result)
    end)

    it("trims leading/trailing whitespace", function()
      assert.equals("hello", helpers._flatten_expr("  hello  "))
    end)
  end)

  -- ── toggle_breakpoint_and_save ─────────────────────────────────────────────

  describe("toggle_breakpoint_and_save", function()
    it("calls dap.toggle_breakpoint and bp.save_async", function()
      helpers.toggle_breakpoint_and_save()
      assert.is_true(_G._test_toggle_called())
      assert.is_true(vim.tbl_contains(_G._test_bp_calls, "save_async"))
    end)
  end)

  -- ── clear_breakpoints_and_save ─────────────────────────────────────────────

  describe("clear_breakpoints_and_save", function()
    it("calls bp.save_async after clearing", function()
      helpers.clear_breakpoints_and_save()
      assert.is_true(vim.tbl_contains(_G._test_bp_calls, "save_async"))
    end)
  end)

  -- ── breakpoints_save ──────────────────────────────────────────────────────

  describe("breakpoints_save", function()
    it("calls mark_dirty then save", function()
      helpers.breakpoints_save()
      local dirty_idx = nil
      local save_idx  = nil
      for i, v in ipairs(_G._test_bp_calls) do
        if v == "mark_dirty" then dirty_idx = i end
        if v == "save"       then save_idx  = i end
      end
      assert.truthy(dirty_idx, "mark_dirty not called")
      assert.truthy(save_idx,  "save not called")
      assert.is_true(dirty_idx < save_idx)
    end)
  end)

  -- ── breakpoints_load ──────────────────────────────────────────────────────

  describe("breakpoints_load", function()
    it("calls bp.load", function()
      helpers.breakpoints_load()
      assert.is_true(vim.tbl_contains(_G._test_bp_calls, "load"))
    end)
  end)

  -- ── breakpoints_picker ────────────────────────────────────────────────────

  describe("breakpoints_picker", function()
    it("delegates to bp.picker", function()
      helpers.breakpoints_picker()
      assert.is_true(vim.tbl_contains(_G._test_bp_calls, "picker"))
    end)
  end)

  -- ── breakpoints_assign_group ──────────────────────────────────────────────

  describe("breakpoints_assign_group", function()
    it("delegates to bp.assign_group", function()
      helpers.breakpoints_assign_group()
      assert.is_true(vim.tbl_contains(_G._test_bp_calls, "assign_group"))
    end)
  end)

  -- ── toggle_dap_view ───────────────────────────────────────────────────────

  describe("toggle_dap_view", function()
    it("calls dap_view.toggle when no action", function()
      helpers.toggle_dap_view()
      assert.is_true(vim.tbl_contains(_G._test_dap_view_calls, "toggle"))
    end)

    it("calls dap_view.open and shows scopes when action=open", function()
      helpers.toggle_dap_view("open")
      assert.is_true(vim.tbl_contains(_G._test_dap_view_calls, "open"))
      assert.is_true(vim.tbl_contains(_G._test_dap_view_calls, "show:scopes"))
    end)
  end)

  -- ── open_repl_view ────────────────────────────────────────────────────────

  describe("open_repl_view", function()
    it("opens dap-view and shows repl", function()
      helpers.open_repl_view()
      assert.is_true(vim.tbl_contains(_G._test_dap_view_calls, "open"))
      assert.is_true(vim.tbl_contains(_G._test_dap_view_calls, "show:repl"))
    end)
  end)

  -- ── bp_icon_for ───────────────────────────────────────────────────────────

  describe("bp_icon_for", function()
    it("returns icon from breakpoints plugin", function()
      local icon = helpers.bp_icon_for("1", "foo.lua")
      assert.equals("●", icon)
    end)
  end)

  -- ── short_path ────────────────────────────────────────────────────────────

  describe("short_path", function()
    it("shortens deep paths to last 2 segments", function()
      assert.equals("c/d.lua", helpers.short_path("a/b/c/d.lua"))
    end)
  end)

  -- ── run_to_cursor ─────────────────────────────────────────────────────────

  describe("run_to_cursor", function()
    it("delegates to dap.run_to_cursor without error", function()
      assert.has_no_error(function() helpers.run_to_cursor() end)
    end)
  end)

  -- ── show_dap_capabilities ────────────────────────────────────────────────

  describe("show_dap_capabilities", function()
    it("notifies WARN when no session", function()
      _G._test_dap_session_active = nil
      local notified = false
      local orig = vim.notify
      vim.notify = function(_, level)
        if level == vim.log.levels.WARN then notified = true end
      end
      helpers.show_dap_capabilities()
      vim.notify = orig
      assert.is_true(notified)
    end)
  end)
end)
