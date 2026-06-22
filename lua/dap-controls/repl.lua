local M = {}

local configured = false

local function open_eval_with_clipboard()
  local helpers = require("dap-controls.helpers")
  local clip = vim.fn.getreg("+")
  if clip == "" or clip == nil then clip = vim.fn.getreg("*") end
  if clip == "" or clip == nil then clip = vim.fn.getreg('"') end
  helpers._open_eval_floating(vim.split(clip or "", "\n", { plain = true }), vim.bo.filetype)
end

function M.setup()
  if configured then return end
  configured = true

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("dap_controls_repl", { clear = true }),
    pattern = "dap-repl",
    callback = function(args)
      local opts = { buffer = args.buf, silent = true, desc = "DAP REPL: paste -> floating eval" }
      vim.keymap.set("n", "p", open_eval_with_clipboard, opts)
      vim.keymap.set("n", "P", open_eval_with_clipboard, opts)
      vim.keymap.set("i", "<C-v>", open_eval_with_clipboard, opts)
      vim.keymap.set("n", "<leader>dE", open_eval_with_clipboard, opts)
    end,
  })
end

return M
