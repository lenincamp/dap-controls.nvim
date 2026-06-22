local M = {}

local configured = { java = false, kotlin = false, javascript = false, autocmds = false }
local js_filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" }
local js_filetypes_set = {}
for _, ft in ipairs(js_filetypes) do
  js_filetypes_set[ft] = true
end

local function real_java_file(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return nil end
  if vim.bo[bufnr].filetype ~= "java" or vim.bo[bufnr].buftype ~= "" then return nil end
  local path = vim.api.nvim_buf_get_name(bufnr)
  return path ~= "" and not vim.startswith(path, "jdt://") and path or nil
end

local function has_jdtls(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1] ~= nil
end

local function setup_java_adapter(bufnr)
  if not real_java_file(bufnr) or not has_jdtls(bufnr) then return end
  local ok, jdtls_dap = pcall(require, "jdtls.dap")
  if ok then jdtls_dap.setup_dap({ hotcodereplace = "auto" }) end
end

local function ensure_java(dap, bufnr)
  if not configured.java then
    local ok, jdtls_nvim = pcall(require, "jdtls-nvim")
    if ok then dap.configurations.java = jdtls_nvim.dap_configurations(bufnr) end
    configured.java = true
  end
  setup_java_adapter(bufnr)
end

local function ensure_kotlin(dap)
  if configured.kotlin then return end

  if not dap.adapters.kotlin and vim.fn.executable("kotlin-debug-adapter") == 1 then
    dap.adapters.kotlin = {
      type = "executable",
      command = "kotlin-debug-adapter",
      options = { auto_continue_if_many_stopped = false },
    }
  end

  dap.configurations.kotlin = {
    {
      type = "kotlin",
      request = "launch",
      name = "This file",
      mainClass = function()
        local root = vim.fs.find("src", { path = vim.uv.cwd(), upward = true, stop = vim.env.HOME })[1] or ""
        return vim.api.nvim_buf_get_name(0)
          :gsub(root, "")
          :gsub("main/kotlin/", "")
          :gsub("%.kt$", "Kt")
          :gsub("/", ".")
          :sub(2)
      end,
      projectRoot = "${workspaceFolder}",
      jsonLogFile = "",
      enableJsonLogging = false,
    },
    {
      type = "kotlin",
      request = "attach",
      name = "Attach to debugging session",
      port = 5005,
      args = {},
      projectRoot = vim.fn.getcwd,
      hostName = "localhost",
      timeout = 2000,
    },
  }

  configured.kotlin = true
end

local function ensure_javascript(dap)
  if configured.javascript then return end

  local js_debug = vim.fn.expand("~/.local/share/nvim/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js")
  if vim.fn.filereadable(js_debug) == 0 then return end

  for _, ft in ipairs(js_filetypes) do
    dap.configurations[ft] = dap.configurations[ft] or {}
    vim.list_extend(dap.configurations[ft], {
      { type = "pwa-node", request = "launch", name = "Launch Node (current file)", program = "${file}", cwd = "${workspaceFolder}" },
      { type = "pwa-node", request = "attach", name = "Attach to Node process", processId = require("dap.utils").pick_process, cwd = "${workspaceFolder}" },
      { type = "pwa-chrome", request = "launch", name = "Launch Chrome (localhost:3000)", url = "http://localhost:3000", webRoot = "${workspaceFolder}" },
    })
  end

  dap.adapters["pwa-node"] = {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = { command = "node", args = { js_debug, "${port}" } },
  }
  dap.adapters["pwa-chrome"] = dap.adapters["pwa-node"]
  configured.javascript = true
end

local function ensure_for_filetype(dap, opts, ft, bufnr)
  if opts.java and ft == "java" then return ensure_java(dap, bufnr) end
  if opts.kotlin and ft == "kotlin" then return ensure_kotlin(dap) end
  if opts.javascript and js_filetypes_set[ft] then return ensure_javascript(dap) end
end

function M.setup(dap, opts)
  if type(dap) ~= "table" then return end
  opts = opts == true and { java = true, kotlin = true, javascript = true } or (opts or {})

  ensure_for_filetype(dap, opts, vim.bo.filetype, vim.api.nvim_get_current_buf())
  if configured.autocmds then return end
  configured.autocmds = true

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("dap_controls_adapters", { clear = true }),
    pattern = { "java", "kotlin", "javascript", "typescript", "javascriptreact", "typescriptreact" },
    callback = function(args)
      ensure_for_filetype(dap, opts, vim.bo[args.buf].filetype, args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("dap_controls_java_dap", { clear = true }),
    callback = function(args)
      local client = args.data and args.data.client_id and vim.lsp.get_client_by_id(args.data.client_id)
      if opts.java and client and client.name == "jdtls" then setup_java_adapter(args.buf) end
    end,
  })
end

return M
