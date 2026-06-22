-- dap-controls.nvim: DAP keymaps, helpers, signs and dap-view patches.
-- Zero personal-config dependencies — requires only nvim-dap (and optionally
-- breakpoints.nvim, picker.nvim, nvim-dap-view, jdtls-nvim).

local M = {}

---@class DapControlsOpts
---@field signs boolean? Apply DAP signs on setup (default: true)
---@field keymaps boolean? Apply DAP keymaps (default: false)
---@field listeners boolean? Open dap-view on attach/launch (default: false)
---@field thread_sync boolean? Apply dap-view thread-sync patches (default: true)
---@field diag_command boolean? Register :DapThreadDiag command (default: true)
---@field repl_paste boolean? Use floating eval for multiline REPL paste (default: false)
---@field breakpoints boolean? Setup breakpoints.nvim integration (default: false)
---@field dap_view boolean|table? Setup dap-view (default: false)
---@field adapters boolean|table? Setup language adapters (default: false)

---@param opts DapControlsOpts?
function M.setup(opts)
  opts = opts or {}
  local ok_dap, dap = pcall(require, "dap")
  local helpers = require("dap-controls.helpers")

  if opts.signs ~= false then
    require("dap-controls.signs").setup()
  end

  if ok_dap and opts.keymaps == true then
    require("dap-controls.keymaps").apply(dap, helpers)
  end

  if ok_dap and opts.listeners == true then
    require("dap-controls.listeners").setup(dap, helpers)
  end

  if opts.thread_sync ~= false then
    local ts = require("dap-controls.thread_sync")
    ts.apply()
    if opts.diag_command ~= false then
      ts.register_diag_command()
    end
  end

  if opts.repl_paste == true then
    require("dap-controls.repl").setup()
  end

  if opts.breakpoints == true then
    require("dap-controls.breakpoints").setup()
  end

  if opts.dap_view and (type(opts.dap_view) ~= "table" or opts.dap_view.enabled ~= false) then
    require("dap-controls.dap_view").setup(type(opts.dap_view) == "table" and opts.dap_view or {})
  end

  if ok_dap and opts.adapters then
    require("dap-controls.adapters").setup(dap, opts.adapters)
  end
end

-- Re-export submodule accessors so consumers can do:
--   local controls = require("dap-controls")
--   controls.helpers.toggle_dap_view()
--   controls.keymaps.apply(dap, helpers)

function M.helpers()
  return require("dap-controls.helpers")
end

function M.keymaps()
  return require("dap-controls.keymaps")
end

function M.signs()
  return require("dap-controls.signs")
end

function M.thread_sync()
  return require("dap-controls.thread_sync")
end

function M.adapters()
  return require("dap-controls.adapters")
end

function M.dap_view()
  return require("dap-controls.dap_view")
end

return M
