local M = {}

---@class DapKeymapSpec
---@field mode string|string[]
---@field lhs string
---@field desc string
---@field view boolean?
---@field action fun(dap: table, helpers: table)

---@type DapKeymapSpec[]
local specs = {
  { mode = "n",        lhs = "<leader>dc",  desc = "Debug: Continue",                   action = function(dap, _)       dap.continue()                              end },
  { mode = "n",        lhs = "<leader>dC",  desc = "Debug: Run to Cursor",              action = function(_, h)         h.run_to_cursor()                           end },
  { mode = "n",        lhs = "<leader>di",  desc = "Debug: Step Into",                  action = function(dap, _)       dap.step_into()                             end },
  { mode = "n",        lhs = "<leader>dO",  desc = "Debug: Step Out",                   action = function(dap, _)       dap.step_out()                              end },
  { mode = "n",        lhs = "<leader>do",  desc = "Debug: Step Over",                  action = function(dap, _)       dap.step_over()                             end },
  { mode = "n",        lhs = "<leader>dP",  desc = "Debug: Pause",                      action = function(dap, _)       dap.pause()                                 end },
  { mode = "n",        lhs = "<leader>db",  desc = "Debug: Toggle Breakpoint",          action = function(_, h)         h.toggle_breakpoint_and_save()              end },
  { mode = "n",        lhs = "<leader>dB",  desc = "Debug: Conditional Breakpoint",     action = function(_, h)         h.conditional_breakpoint_prompt()           end },
  { mode = "n",        lhs = "<leader>dL",  desc = "Debug: Logpoint",                   action = function(_, h)         h.logpoint_prompt()                         end },
  { mode = "n",        lhs = "<leader>dD",  desc = "Debug: Clear breakpoints",          action = function(_, h)         h.clear_breakpoints_and_save()              end },
  { mode = "n",        lhs = "<leader>dl",  desc = "Debug: Run Last",                   action = function(dap, _)       dap.run_last()                              end },
  { mode = "n",        lhs = "<leader>dt",  desc = "Debug: Terminate",                  action = function(dap, _)       dap.terminate()                             end },
  { mode = "n",        lhs = "<leader>dd",  desc = "Debug: Disconnect",                 action = function(dap, _)       dap.disconnect()                            end },
  { mode = "n",        lhs = "<leader>dr",  desc = "Debug: Open REPL View",  view = true, action = function(_, h)       h.open_repl_view()                          end },
  { mode = "x",        lhs = "<leader>dr",  desc = "Debug: Eval Selection in REPL",     action = function(_, h)         h.eval_visual_selection_in_repl()           end },
  { mode = "n",        lhs = "<leader>ds",  desc = "Debug: Session",                    action = function(_, h)         h.show_session()                            end },
  { mode = "n",        lhs = "<leader>dw",  desc = "Debug: Widgets",                    action = function(_, h)         h.hover_widget()                            end },
  { mode = { "n","v"}, lhs = "<leader>de",  desc = "Debug: Eval",                       action = function(_, h)         h.hover_widget()                            end },
  { mode = "n",        lhs = "<leader>dE",  desc = "Debug: Eval/Set Expression",        action = function(_, h)         h.eval_expression_prompt()                  end },
  { mode = "n",        lhs = "<leader>dS",  desc = "Debug: Set Expression",             action = function(_, h)         h.set_expression_prompt()                   end },
  { mode = "n",        lhs = "<leader>dW",  desc = "Debug: Add Watch",       view = true, action = function(_, h)       h.add_watch_prompt()                        end },
  { mode = "x",        lhs = "<leader>dW",  desc = "Debug: Add Watch from Selection", view = true, action = function(_, h) h.add_watch_from_visual_selection()      end },
  { mode = "n",        lhs = "<leader>dj",  desc = "Debug: Down (stack)",               action = function(dap, _)       dap.down()                                  end },
  { mode = "n",        lhs = "<leader>dk",  desc = "Debug: Up (stack)",                 action = function(dap, _)       dap.up()                                    end },
  { mode = "n",        lhs = "<leader>dg",  desc = "Debug: Go to Line",                 action = function(_, h)         h.goto_line_prompt()                        end },
  { mode = "n",        lhs = "<leader>dm",  desc = "Debug: Method Breakpoint Picker",   action = function(_, h)         h.run_to_method_breakpoint()                end },
  { mode = "n",        lhs = "<leader>da",  desc = "Debug: Run with Args",              action = function(_, h)         h.continue_with_args_prompt()               end },
  { mode = "n",        lhs = "<leader>du",  desc = "Debug: Toggle DAP View", view = true, action = function(_, h)       h.toggle_dap_view()                         end },
  { mode = "n",        lhs = "<leader>d?",  desc = "Debug: Show Adapter Capabilities",  action = function(_, h)         h.show_dap_capabilities()                   end },
  { mode = "n",        lhs = "<leader>dbs", desc = "Breakpoints: Save",                 action = function(_, h)         h.breakpoints_save()                        end },
  { mode = "n",        lhs = "<leader>dbL", desc = "Breakpoints: Load",                 action = function(_, h)         h.breakpoints_load()                        end },
  { mode = "n",        lhs = "<leader>dbg", desc = "Breakpoints: Assign group",         action = function(_, h)         h.breakpoints_assign_group()                end },
  { mode = "n",        lhs = "<leader>dbp", desc = "Breakpoints: Browse by group",      action = function(_, h)         h.breakpoints_picker()                      end },
}

function M.lazy_specs()
  local lazy = {}
  for _, spec in ipairs(specs) do
    lazy[#lazy + 1] = {
      mode   = spec.mode,
      lhs    = spec.lhs,
      desc   = spec.desc,
      loader = spec.view and { "nvim-dap", "nvim-dap-view" } or nil,
    }
  end
  return lazy
end

function M.lazy_keys()
  local keys = {}
  for _, spec in ipairs(specs) do
    keys[#keys + 1] = { spec.lhs, mode = spec.mode, desc = spec.desc }
  end
  return keys
end

function M.apply(dap, helpers)
  if type(dap) ~= "table" or type(helpers) ~= "table" then return end
  for _, spec in ipairs(specs) do
    vim.keymap.set(spec.mode, spec.lhs, function()
      spec.action(dap, helpers)
    end, { desc = spec.desc })
  end
end

return M
