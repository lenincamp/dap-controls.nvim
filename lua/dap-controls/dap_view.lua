local M = {}

local configured = false

local terminal_hide = { "java", "kotlin", "apex", "apex-replay-debugger" }
local sections = { "scopes", "watches", "breakpoints", "threads", "repl", "console", "exceptions", "sessions" }

local labels = {
  scopes = { label = "󰫧 Variables", keymap = "1" },
  watches = { label = "󰈈 Watch", keymap = "2" },
  breakpoints = { label = "󰃤 Breakpoints", keymap = "3" },
  threads = { label = "󱍢 Call Stack", keymap = "4" },
  repl = { label = "󰞷 REPL", keymap = "5" },
  console = { label = "󰆍 Console", keymap = "6" },
  exceptions = { label = "󰀦 Exceptions", keymap = "7" },
  sessions = { label = "󰒋 Sessions", keymap = "8" },
}

local function dap_view_opts()
  return {
    auto_toggle = true,
    follow_tab = true,
    switchbuf = "usetab,uselast",
    winbar = {
      show = true,
      show_keymap_hints = true,
      sections = sections,
      default_section = "scopes",
      base_sections = labels,
    },
    windows = {
      size = 0.28,
      position = "below",
      terminal = { size = 0.4, position = "right", hide = terminal_hide },
    },
    render = {
      breakpoints = {
        format = function(line, lnum, path)
          local helpers = require("dap-controls.helpers")
          return {
            { text = helpers.bp_icon_for(lnum, path), hl = "DapBreakpoint", separator = " " },
            { text = helpers.short_path(path), hl = "FileName" },
            { text = lnum, hl = "LineNumber" },
            { text = line, hl = true },
          }
        end,
        align = true,
      },
    },
    virtual_text = {
      enabled = true,
      position = "eol",
    },
  }
end

local function setup_dap_view_buffer(args)
  local opt = vim.opt_local
  opt.statusline = " "
  opt.number = false
  opt.relativenumber = false
  opt.cursorline = true
  opt.signcolumn = "no"
  opt.foldcolumn = "0"
  opt.wrap = false
  opt.list = false

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = args.buf, silent = true, desc = desc })
  end
  map("q", "<cmd>DapViewClose<cr>", "Debug: Close panel")
  map("<Tab>", "<cmd>DapViewNavigate! 1<cr>", "Debug: Next tab")
  map("<S-Tab>", "<cmd>DapViewNavigate! -1<cr>", "Debug: Prev tab")
  map("<leader>dW", "<cmd>DapViewWatch<cr>", "Debug: Add watch from dap-view")

  vim.keymap.set("x", "<leader>dW", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local srow, scol = unpack(vim.api.nvim_buf_get_mark(bufnr, "<"))
    local erow, ecol = unpack(vim.api.nvim_buf_get_mark(bufnr, ">"))
    if srow == 0 or erow == 0 then return end
    if srow > erow or (srow == erow and scol > ecol) then
      srow, erow, scol, ecol = erow, srow, ecol, scol
    end
    local expr = table.concat(vim.api.nvim_buf_get_text(bufnr, srow - 1, scol, erow - 1, ecol + 1, {}), "\n")
    expr = vim.trim(expr or ""):gsub("%s+", " ")
    if expr == "" then return end
    local ok, dap_view = pcall(require, "dap-view")
    if ok then dap_view.add_expr(expr, true) end
  end, { buffer = args.buf, silent = true, desc = "Debug: Add watch from dap-view selection" })
end

function M.setup(opts)
  if configured then return end
  configured = true

  local ok, dap_view = pcall(require, "dap-view")
  if not ok then return end

  opts = opts or {}
  dap_view.setup(vim.tbl_deep_extend("force", dap_view_opts(), opts.override or {}))

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("dap_controls_view", { clear = true }),
    pattern = "dap-view",
    callback = setup_dap_view_buffer,
  })
end

M._opts = dap_view_opts

return M
