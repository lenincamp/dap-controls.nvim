-- Minimal init for dap-controls.nvim tests.
-- Adds plugin to rtp and stubs all external dependencies.
vim.cmd("set rtp+=.")

-- ── Mock: dap ────────────────────────────────────────────────────────────────

local dap_breakpoints_data = {}

local mock_dap_breakpoints = {}
function mock_dap_breakpoints.get(bufnr)
  if bufnr then return { [bufnr] = dap_breakpoints_data[bufnr] or {} } end
  return dap_breakpoints_data
end
function mock_dap_breakpoints.set(opts, bufnr, line)
  dap_breakpoints_data[bufnr] = dap_breakpoints_data[bufnr] or {}
  local entry = { line = line }
  if opts.condition     then entry.condition     = opts.condition     end
  if opts.log_message   then entry.logMessage    = opts.log_message   end
  if opts.hit_condition then entry.hitCondition  = opts.hit_condition end
  table.insert(dap_breakpoints_data[bufnr], entry)
end
function mock_dap_breakpoints.remove(bufnr, line)
  local list = dap_breakpoints_data[bufnr]
  if not list then return end
  for i, bp in ipairs(list) do
    if bp.line == line then table.remove(list, i); break end
  end
end
function mock_dap_breakpoints.clear()
  dap_breakpoints_data = {}
end

_G._test_dap_bp        = mock_dap_breakpoints
_G._test_dap_bp_data   = function() return dap_breakpoints_data end
_G._test_dap_bp_reset  = function() dap_breakpoints_data = {} end

local mock_dap_session = {
  stopped_thread_id = nil,
  current_frame     = nil,
  threads           = {},
  capabilities      = {},
  config            = { type = "generic" },
}

_G._test_dap_session = mock_dap_session

local toggle_called = false
local repl_toggled  = false

local mock_dap = {
  session          = function() return _G._test_dap_session_active end,
  continue         = function() end,
  step_into        = function() end,
  step_out         = function() end,
  step_over        = function() end,
  pause            = function() end,
  run_last         = function() end,
  terminate        = function() end,
  disconnect       = function() end,
  down             = function() end,
  up               = function() end,
  run_to_cursor    = function() end,
  toggle_breakpoint = function() toggle_called = true end,
  set_breakpoint   = function() end,
  clear_breakpoints = function() end,
  goto_            = function() end,
  restart_frame    = function() end,
  repl             = { toggle = function() repl_toggled = true end, append = function() end },
  listeners        = {
    after  = { event_stopped = {} },
    before = {
      event_stopped    = {},
      event_terminated = {},
      event_exited     = {},
      disconnect       = {},
      attach           = {},
      launch           = {},
    },
  },
}

_G._test_dap             = mock_dap
_G._test_toggle_called   = function() return toggle_called end
_G._test_toggle_reset    = function() toggle_called = false end
_G._test_repl_toggled    = function() return repl_toggled  end
_G._test_repl_reset      = function() repl_toggled = false  end

package.loaded["dap"]             = mock_dap
package.loaded["dap.breakpoints"] = mock_dap_breakpoints
package.loaded["dap.ui.widgets"]  = { hover = function() end }

-- ── Mock: dap.session ────────────────────────────────────────────────────────

local mock_session_module = {
  _frame_set = function(self, frame) self.current_frame = frame end,
  _step      = function(self, step, params) end,
}
_G._test_dap_session_module = mock_session_module
package.loaded["dap.session"] = mock_session_module

-- ── Mock: dap-view ───────────────────────────────────────────────────────────

_G._test_dap_view_calls = {}
package.loaded["dap-view"] = {
  open      = function() table.insert(_G._test_dap_view_calls, "open")      end,
  toggle    = function() table.insert(_G._test_dap_view_calls, "toggle")    end,
  show_view = function(v) table.insert(_G._test_dap_view_calls, "show:"..v) end,
  add_expr  = function(expr) table.insert(_G._test_dap_view_calls, "add:"..expr) end,
}
package.loaded["dap-view.guard"] = {
  expect_stopped = function() return true end,
}

-- ── Mock: breakpoints.nvim ───────────────────────────────────────────────────

_G._test_bp_calls = {}
package.loaded["breakpoints"] = {
  save_async    = function() table.insert(_G._test_bp_calls, "save_async")   end,
  save          = function() table.insert(_G._test_bp_calls, "save")         end,
  load          = function() table.insert(_G._test_bp_calls, "load")         end,
  mark_dirty    = function() table.insert(_G._test_bp_calls, "mark_dirty")   end,
  picker        = function() table.insert(_G._test_bp_calls, "picker")       end,
  assign_group  = function() table.insert(_G._test_bp_calls, "assign_group") end,
  icon_for      = function(lnum, path) return "●" end,
  short_path    = function(path)
    local parts = vim.split(path or "", "/", { plain = true })
    if #parts > 2 then return parts[#parts-1] .. "/" .. parts[#parts] end
    return path or ""
  end,
}

-- ── Mock: picker.nvim ────────────────────────────────────────────────────────

_G._test_picker_calls = {}
package.loaded["picker"] = {
  select_items = function(items, opts, on_choice)
    table.insert(_G._test_picker_calls, { items = items, opts = opts, on_choice = on_choice })
  end,
}
