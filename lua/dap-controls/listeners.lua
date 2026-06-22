local M = {}

local configured = false

function M.setup(dap, helpers)
  if configured or type(dap) ~= "table" or type(helpers) ~= "table" then return end
  configured = true

  dap.listeners.before.attach["dap-controls-view"] = function()
    helpers.toggle_dap_view("open")
  end

  dap.listeners.before.launch["dap-controls-view"] = function()
    helpers.toggle_dap_view("open")
  end
end

return M
