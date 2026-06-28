local M = {}

local ok_dap, dap = pcall(require, "dap")
if not ok_dap then
  return M
end

local widgets = require("dap.ui.widgets")

-- ── Session helpers ──────────────────────────────────────────────────────────

local function session_capabilities(session)
  return (session and session.capabilities) or {}
end

local function normalize_error(err)
  if not err then return nil end
  if type(err) == "string" then return err end
  if type(err) ~= "table" then return tostring(err) end

  local msg = err.message
  if not msg and err.body and err.body.error then
    msg = err.body.error.message
  end
  if not msg and err.error then
    msg = err.error.message or err.error
  end
  return msg or vim.inspect(err)
end

local function current_frame_id(session)
  local frame = session and session.current_frame
  return frame and frame.id or nil
end

local function session_request(session, command, args, on_success, retry_count)
  if not session then
    vim.notify("No active DAP session", vim.log.levels.WARN)
    return
  end

  local is_java = session.config and session.config.type == "java"
  if is_java then
    local ok_recovery, recovery = pcall(require, "jdtls-nvim.dap_recovery")
    if ok_recovery then
      recovery.request_with_recovery(session, command, args, on_success, nil, retry_count)
      return
    end
  end

  session:request(command, args, function(err, response)
    if err then
      local msg = normalize_error(err)
      vim.schedule(function()
        vim.notify(string.format("DAP %s error: %s", command, msg), vim.log.levels.ERROR)
      end)
      return
    end
    if on_success then on_success(response) end
  end)
end

local function eval_in_repl(session, expr)
  local frame_id = current_frame_id(session)
  session_request(session, "evaluate", {
    expression = expr,
    context    = "repl",
    frameId    = frame_id,
  }, function(response)
    local result = response and response.result
    if result and result ~= "" then
      dap.repl.append(result)
      dap.repl.append("\n")
    end
  end)
end

-- ── Eval helpers ─────────────────────────────────────────────────────────────

local function flatten_expr(text)
  if not text or text == "" then return "" end
  local cleaned = {}
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    cleaned[#cleaned + 1] = line:gsub("//[^\n]*$", "")
  end
  local joined = table.concat(cleaned, " ")
  joined = joined:gsub("%s+", " ")
  return vim.trim(joined)
end

local function eval_or_set(expr)
  expr = flatten_expr(expr)
  if expr == "" then return end

  local session = dap.session()
  if not session or not session.stopped_thread_id then
    vim.notify("Debugger must be stopped to eval/set expression", vim.log.levels.INFO)
    return
  end

  local caps = session_capabilities(session)
  local lhs, rhs = expr:match("^([%w_%.$%[%]%(%)]+)%s*=%s*(.+)$")

  if lhs and rhs and caps.supportsSetExpression then
    session_request(session, "setExpression", {
      expression = vim.trim(lhs),
      value      = vim.trim(rhs),
      frameId    = current_frame_id(session),
    })
  else
    eval_in_repl(session, expr)
  end

  local ok_dv, dap_view = pcall(require, "dap-view")
  if ok_dv then
    dap_view.open()
    dap_view.show_view("repl")
  else
    dap.repl.toggle()
  end
end

local function open_eval_floating(initial_lines, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype   = "nofile"
  if ft and ft ~= "" then
    pcall(function() vim.bo[buf].filetype = ft end)
  end
  if initial_lines and #initial_lines > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_lines)
  end

  local width  = math.min(100, math.floor(vim.o.columns * 0.8))
  local height = math.min(15, math.max(6, math.floor(vim.o.lines * 0.35)))
  local row    = math.floor((vim.o.lines - height) / 2) - 1
  local col    = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative   = "editor",
    row        = row,
    col        = col,
    width      = width,
    height     = height,
    style      = "minimal",
    border     = "rounded",
    title      = " Debug · Evaluate  (<C-CR>/<C-s> submit · q close) ",
    title_pos  = "center",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    close()
    eval_or_set(table.concat(lines, "\n"))
  end

  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set({ "n", "i" }, "<C-CR>",  submit, opts)
  vim.keymap.set({ "n", "i" }, "<C-s>",   submit, opts)
  vim.keymap.set({ "n", "i" }, "<D-CR>",  submit, opts)
  vim.keymap.set("n",           "q",       close,  opts)
  vim.keymap.set("n",           "<Esc>",   close,  opts)
end

local function visual_selection_text()
  local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, "<"))
  local end_row, end_col     = unpack(vim.api.nvim_buf_get_mark(0, ">"))
  if start_row == 0 or end_row == 0 then return nil end
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  if #lines == 0 then return nil end
  lines[1]       = string.sub(lines[1], start_col + 1)
  lines[#lines]  = string.sub(lines[#lines], 1, end_col + 1)
  return vim.trim(table.concat(lines, "\n"))
end

-- ── Watch helpers ────────────────────────────────────────────────────────────

local LISTENER_ID          = "nvim-pure-watch-queue"
local pending_watch_exprs  = {}

local function is_debugger_stopped()
  local session = dap.session()
  return session ~= nil and session.stopped_thread_id ~= nil
end

local function flush_pending_watches()
  if next(pending_watch_exprs) == nil then return end

  local ok_dap_view, dap_view = pcall(require, "dap-view")
  if not ok_dap_view then return end

  for expr, _ in pairs(pending_watch_exprs) do
    dap_view.add_expr(expr, true)
    pending_watch_exprs[expr] = nil
  end
end

local function setup_watch_listeners()
  dap.listeners.after.event_stopped[LISTENER_ID] = function()
    vim.schedule(flush_pending_watches)
  end

  dap.listeners.before.event_terminated[LISTENER_ID] = function()
    pending_watch_exprs = {}
  end

  dap.listeners.before.event_exited[LISTENER_ID] = function()
    pending_watch_exprs = {}
  end
end

local function add_watch_expression(expr)
  if not expr or vim.trim(expr) == "" then return end
  expr = vim.trim(expr):gsub("%s+", " ")

  if not is_debugger_stopped() then
    pending_watch_exprs[expr] = true
    vim.notify("Watch queued: it will be added on next debugger stop", vim.log.levels.INFO)
    return
  end

  local ok_dap_view, dap_view = pcall(require, "dap-view")
  if not ok_dap_view then
    vim.notify("dap-view is not available", vim.log.levels.WARN)
    return
  end
  dap_view.add_expr(expr, true)
end

-- ── Run-to helpers ───────────────────────────────────────────────────────────

local function debug_enabled()
  return vim.g.dap_method_jump_debug == true
end

local function debug_log(msg)
  if debug_enabled() then
    vim.notify("[dap-method-jump] " .. msg, vim.log.levels.INFO)
  end
end

local function get_enclosing_method_range(bufnr, line)
  local provider = vim.b[bufnr].dap_method_range_provider
  if type(provider) == "function" then
    return provider(bufnr, line)
  end

  local ft   = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok_parser or not parser then return nil, nil end

  local trees = parser:parse()
  if not trees or not trees[1] then return nil, nil end

  local root = trees[1]:root()
  if not root then return nil, nil end

  local method_types = {
    java       = { method_declaration = true, constructor_declaration = true },
    kotlin     = { function_declaration = true },
    typescript = { method_definition = true, function_declaration = true },
    javascript = { method_definition = true, function_declaration = true },
    python     = { function_definition = true },
    lua        = { function_declaration = true },
    go         = { function_declaration = true, method_declaration = true },
  }
  local valid = method_types[lang] or { method_declaration = true, function_declaration = true }

  local node = root:named_descendant_for_range(line - 1, 0, line - 1, 0)
  while node do
    if valid[node:type()] then
      local start_row, _, end_row, _ = node:range()
      return start_row + 1, end_row + 1
    end
    node = node:parent()
  end

  return nil, nil
end

local function get_method_breakpoints(bufnr, start_line, end_line)
  local ok_breakpoints, dap_breakpoints = pcall(require, "dap.breakpoints")
  if not ok_breakpoints then return {} end

  local all    = dap_breakpoints.get(bufnr)[bufnr] or {}
  local result = {}
  for _, breakpoint in ipairs(all) do
    if breakpoint.line >= start_line and breakpoint.line <= end_line then
      result[#result + 1] = breakpoint.line
    end
  end

  table.sort(result)
  return result
end

local function resolve_source_win(bufnr, preferred_win)
  if preferred_win and vim.api.nvim_win_is_valid(preferred_win)
      and vim.api.nvim_win_get_buf(preferred_win) == bufnr then
    return preferred_win
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end

  return nil
end

local function has_breakpoint_at(bufnr, line)
  local ok_breakpoints, dap_breakpoints = pcall(require, "dap.breakpoints")
  if not ok_breakpoints then return false end
  local bps = dap_breakpoints.get(bufnr)[bufnr] or {}
  for _, breakpoint in ipairs(bps) do
    if breakpoint.line == line then return true end
  end
  return false
end

local function set_breakpoint_at(bufnr, line, source_win)
  local win = resolve_source_win(bufnr, source_win)
  if not win then
    vim.notify("Cannot find source window to set temporary breakpoint", vim.log.levels.WARN)
    return false
  end

  vim.api.nvim_win_call(win, function()
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    dap.set_breakpoint()
  end)
  return true
end

local function remove_breakpoint_at(bufnr, line)
  local ok_breakpoints, dap_breakpoints = pcall(require, "dap.breakpoints")
  if not ok_breakpoints then return end
  dap_breakpoints.remove(bufnr, line)

  local session = dap.session()
  if session then
    local bps = dap_breakpoints.get()
    session:set_breakpoints(bps, function() end)
  end
end

local function continue_to_temp_breakpoint(bufnr, target_line, source_win)
  local temp_added = false
  if not has_breakpoint_at(bufnr, target_line) then
    temp_added = set_breakpoint_at(bufnr, target_line, source_win)
    if not temp_added then return end
    debug_log(string.format("temp breakpoint added at %d", target_line))
  else
    debug_log(string.format("reusing existing breakpoint at %d", target_line))
  end

  local cleanup_id = "nvim-pure-method-breakpoint-cleanup"
  local function cleanup()
    dap.listeners.before.event_stopped[cleanup_id]    = nil
    dap.listeners.before.event_terminated[cleanup_id] = nil
    dap.listeners.before.event_exited[cleanup_id]     = nil
    dap.listeners.before.disconnect[cleanup_id]       = nil
    if temp_added then
      vim.schedule(function()
        remove_breakpoint_at(bufnr, target_line)
        debug_log(string.format("temp breakpoint removed at %d", target_line))
      end)
    end
  end

  dap.listeners.before.event_stopped[cleanup_id]    = cleanup
  dap.listeners.before.event_terminated[cleanup_id] = cleanup
  dap.listeners.before.event_exited[cleanup_id]     = cleanup
  dap.listeners.before.disconnect[cleanup_id]       = cleanup

  dap.continue()
end

local function current_frame_line(session)
  local frame = session and session.current_frame
  if frame and type(frame.line) == "number" then
    return frame.line
  end
  return nil
end

local function current_source_line(bufnr, source_win)
  local win = resolve_source_win(bufnr, source_win)
  if not win then return nil end
  if vim.api.nvim_win_get_buf(win) ~= bufnr then return nil end
  return vim.api.nvim_win_get_cursor(win)[1]
end

-- ── Public API ───────────────────────────────────────────────────────────────

setup_watch_listeners()

function M.java_project_name(path_hint)
  local ok, jdtls_nvim = pcall(require, "jdtls-nvim")
  if ok then return jdtls_nvim.project_name(path_hint) end
  return vim.g.jdtls_nvim_project_name or nil
end

function M.run_to_cursor()
  dap.run_to_cursor()
end

function M.run_to_method_breakpoint()
  local session = dap.session()
  if not session or not session.stopped_thread_id then
    vim.notify("Debugger must be stopped to use method breakpoint picker", vim.log.levels.INFO)
    return
  end

  local bufnr       = vim.api.nvim_get_current_buf()
  local source_win  = vim.api.nvim_get_current_win()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local start_line, end_line = get_enclosing_method_range(bufnr, current_line)
  if not start_line or not end_line then
    vim.notify("No enclosing method found at cursor", vim.log.levels.WARN)
    return
  end

  local method_breakpoints = get_method_breakpoints(bufnr, start_line, end_line)
  if #method_breakpoints == 0 then
    vim.notify("No breakpoints found in current method", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, line in ipairs(method_breakpoints) do
    local mark = (line == current_line) and " (current)" or ""
    items[#items + 1] = { line = line, label = string.format("line %d%s", line, mark) }
  end

  local ok, picker = pcall(require, "picker")
  local select_items = (ok and type(picker.select_items) == "function") and picker.select_items
    or function(list, opts, on_choice)
      vim.ui.select(list, { prompt = opts.prompt, format_item = opts.format_item }, on_choice)
    end

  select_items(items, {
    prompt           = "Run to method breakpoint",
    search_threshold = 0,
    format_item      = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    local target_line = choice.line
    debug_log(string.format("selected target=%d current=%d", target_line, current_line))

    if target_line == current_line then
      vim.notify("Already at selected breakpoint", vim.log.levels.INFO)
      return
    end

    if target_line > current_line then
      debug_log("forward jump via continue_to_temp_breakpoint")
      continue_to_temp_breakpoint(bufnr, target_line, source_win)
      return
    end

    if not session.capabilities or not session.capabilities.supportsRestartFrame then
      vim.notify("Adapter does not support restart frame; rerun to hit earlier breakpoint", vim.log.levels.WARN)
      return
    end

    local listener_id = "nvim-pure-run-to-method-breakpoint-restart"
    dap.listeners.after.event_stopped[listener_id] = function()
      dap.listeners.after.event_stopped[listener_id] = nil
      local function maybe_continue(attempt)
        local active      = dap.session()
        local frame_line  = current_frame_line(active)
        local source_line = current_source_line(bufnr, source_win)
        local observed    = source_line or frame_line

        debug_log(string.format(
          "after restart attempt=%d frame=%s source=%s target=%d",
          attempt, tostring(frame_line), tostring(source_line), target_line
        ))

        if observed == target_line then
          debug_log("already at target after restart")
          return
        end

        if observed and observed > target_line then
          if attempt < 2 then
            vim.defer_fn(function() maybe_continue(attempt + 1) end, 30)
            return
          end
          debug_log("restart landed after target; aborting continue to avoid +1 overshoot")
          return
        end

        debug_log("backward jump continuing to temp breakpoint")
        continue_to_temp_breakpoint(bufnr, target_line, source_win)
      end

      vim.schedule(function() maybe_continue(1) end)
    end

    debug_log("executing restart_frame")
    dap.restart_frame()
  end)
end

function M.toggle_breakpoint_and_save()
  dap.toggle_breakpoint()
  local ok_bp, bp = pcall(require, "breakpoints")
  if ok_bp then bp.save_async() end
end

function M.conditional_breakpoint_prompt()
  vim.ui.input({ prompt = "Breakpoint condition: ", scope = "line" }, function(condition)
    if condition == nil then return end
    dap.set_breakpoint(condition)
    local ok_bp, bp = pcall(require, "breakpoints")
    if ok_bp then bp.save_async() end
  end)
end

function M.logpoint_prompt()
  vim.ui.input({ prompt = "Logpoint message: ", scope = "line" }, function(message)
    if message == nil then return end
    dap.set_breakpoint(nil, nil, message)
    local ok_bp, bp = pcall(require, "breakpoints")
    if ok_bp then bp.save_async() end
  end)
end

function M.clear_breakpoints_and_save()
  dap.clear_breakpoints()
  local ok_bp, bp = pcall(require, "breakpoints")
  if ok_bp then bp.save_async() end
end

function M.show_session()
  dap.session()
end

function M.hover_widget()
  widgets.hover()
end

M._open_eval_floating = function(initial_lines, ft) open_eval_floating(initial_lines, ft) end
M._flatten_expr       = flatten_expr

function M.eval_expression_prompt()
  open_eval_floating(nil, vim.bo.filetype)
end

function M.set_expression_prompt()
  vim.ui.input({ prompt = "Set expression (name=value): ", scope = "cursor" }, function(expr)
    if not expr or vim.trim(expr) == "" then return end

    local session = dap.session()
    if not session or not session.stopped_thread_id then
      vim.notify("Debugger must be stopped to set variable", vim.log.levels.INFO)
      return
    end

    local trimmed   = vim.trim(expr)
    local lhs, rhs  = trimmed:match("^([%w_%.$%[%]%(%)]+)%s*=%s*(.+)$")
    if not lhs or not rhs then
      vim.notify("Use format: variable=value", vim.log.levels.WARN)
      return
    end

    local caps = session_capabilities(session)
    if caps.supportsSetExpression then
      session_request(session, "setExpression", {
        expression = vim.trim(lhs),
        value      = vim.trim(rhs),
        frameId    = current_frame_id(session),
      })
      return
    end

    eval_in_repl(session, string.format("%s = %s", vim.trim(lhs), vim.trim(rhs)))
  end)
end

function M.show_dap_capabilities()
  local session = dap.session()
  if not session then
    vim.notify("No active DAP session", vim.log.levels.WARN)
    return
  end

  local caps = session_capabilities(session)
  vim.notify(vim.inspect({
    adapter                  = session.config and session.config.type,
    supportsSetExpression    = caps.supportsSetExpression,
    supportsSetVariable      = caps.supportsSetVariable,
    supportsEvaluateForHovers = caps.supportsEvaluateForHovers,
    supportsRestartFrame     = caps.supportsRestartFrame,
  }), vim.log.levels.INFO)
end

function M.add_watch_prompt()
  vim.ui.input({ prompt = "Watch expression: ", scope = "cursor" }, function(expr)
    add_watch_expression(expr)
  end)
end

function M.add_watch_from_visual_selection()
  add_watch_expression(visual_selection_text())
end

function M.open_repl_view()
  local ok_dv, dap_view = pcall(require, "dap-view")
  if ok_dv then
    dap_view.open()
    dap_view.show_view("repl")
    return
  end
  dap.repl.toggle()
end

function M.eval_visual_selection_in_repl()
  local raw = visual_selection_text()
  if not raw or raw == "" then return end

  if raw:find("\n") then
    open_eval_floating(vim.split(raw, "\n", { plain = true }), vim.bo.filetype)
  else
    eval_or_set(raw)
  end
end

function M.goto_line_prompt()
  vim.ui.input({ prompt = "Line: ", scope = "buffer" }, function(line)
    if line == nil then return end
    dap.goto_(tonumber(line))
  end)
end

function M.continue_with_args_prompt()
  vim.ui.input({ prompt = "Args: ", scope = "project" }, function(args)
    if args == nil then return end
    dap.continue({
      before = function(config)
        config.args = vim.split(args or "", " ")
        return config
      end,
    })
  end)
end

function M.toggle_dap_view(action)
  local ok_dv, dap_view = pcall(require, "dap-view")
  if not ok_dv then return end
  dap_view[action or "toggle"]()
  if action == "open" then dap_view.show_view("scopes") end
end

function M.breakpoints_save()
  local ok_bp, bp = pcall(require, "breakpoints")
  if not ok_bp then return end
  bp.mark_dirty()
  bp.save()
end

function M.breakpoints_load()
  local ok_bp, bp = pcall(require, "breakpoints")
  if ok_bp then bp.load() end
end

function M.breakpoints_assign_group()
  local ok_bp, bp = pcall(require, "breakpoints")
  if ok_bp then bp.assign_group() end
end

function M.breakpoints_picker()
  local ok_bp, bp = pcall(require, "breakpoints")
  if ok_bp then bp.picker() end
end

function M.bp_icon_for(lnum_str, path)
  local ok_bp, bp = pcall(require, "breakpoints")
  if ok_bp then return bp.icon_for(lnum_str, path) end
  return "●"
end

function M.short_path(path)
  local ok_bp, bp = pcall(require, "breakpoints")
  if ok_bp then return bp.short_path(path) end
  local parts = vim.split(path or "", "/", { plain = true })
  if #parts > 2 then
    return parts[#parts - 1] .. "/" .. parts[#parts]
  end
  return path or ""
end

return M
