local M = {}

local configured = false

local function setup_highlights()
  vim.api.nvim_set_hl(0, "DapBreakpoint",         { link = "DiagnosticError" })
  vim.api.nvim_set_hl(0, "DapBreakpointCondition", { link = "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "DapLogPoint",            { link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "DapStopped",             { link = "DiagnosticHint" })
  vim.api.nvim_set_hl(0, "DapStoppedLine",         { link = "CursorLine" })
  vim.api.nvim_set_hl(0, "DapBreakpointRejected",  { link = "Comment" })
end

function M.setup()
  if not configured then
    configured = true
    vim.api.nvim_create_autocmd("ColorScheme", {
      group    = vim.api.nvim_create_augroup("dap_controls_hl", { clear = true }),
      callback = setup_highlights,
    })
    setup_highlights()
  end

  vim.fn.sign_define("DapBreakpoint",         { text = "●", texthl = "DapBreakpoint",         linehl = "",             numhl = "" })
  vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition", linehl = "",             numhl = "" })
  vim.fn.sign_define("DapLogPoint",            { text = "◉", texthl = "DapLogPoint",            linehl = "",             numhl = "" })
  vim.fn.sign_define("DapStopped",             { text = "▶", texthl = "DapStopped",             linehl = "DapStoppedLine", numhl = "DapStopped" })
  vim.fn.sign_define("DapBreakpointRejected",  { text = "○", texthl = "DapBreakpointRejected",  linehl = "",             numhl = "" })
end

return M
