-- thread_sync: patches for dap-view's frame navigation.
--
-- Problem: dap-view's frame navigation calls session:_frame_set() which
-- doesn't update stopped_thread_id.  Also, guard.expect_stopped() blocks
-- actions when stopped_thread_id is nil.  And dap.continue() shows a confusing
-- picker menu instead of continuing.  All three paths need recovery.

local M = {}

local function find_thread_for_frame(session, frame_id)
  if not session or not frame_id then return nil end
  for _, thread in pairs(session.threads or {}) do
    for _, f in ipairs(thread.frames or {}) do
      if f.id == frame_id then return thread.id end
    end
  end
  return nil
end

local function find_any_stopped_thread(session)
  if not session then return nil end
  for tid, thread in pairs(session.threads or {}) do
    if thread and thread.stopped then return tid end
  end
  return nil
end

local function recover_stopped_thread_id(session)
  if not session or session.stopped_thread_id then return end
  local tid = find_any_stopped_thread(session)
  if not tid then
    tid = find_thread_for_frame(session,
            session.current_frame and session.current_frame.id)
  end
  if not tid then
    for id, thread in pairs(session.threads or {}) do
      if thread.frames and #thread.frames > 0 then
        tid = id
        break
      end
    end
  end
  if tid then session.stopped_thread_id = tid end
end

-- Exposed for tests
M._find_thread_for_frame      = find_thread_for_frame
M._find_any_stopped_thread    = find_any_stopped_thread
M._recover_stopped_thread_id  = recover_stopped_thread_id

function M.apply()
  if vim.g.nvim_pure_dap_thread_sync then return end
  vim.g.nvim_pure_dap_thread_sync = true

  local ok_dap, dap_mod = pcall(require, "dap")
  if not ok_dap then return end

  local ok_sess, Session = pcall(require, "dap.session")
  if ok_sess and type(Session._frame_set) == "function" then
    local orig_frame_set = Session._frame_set
    Session._frame_set = function(self, frame)
      if self and frame and frame.id then
        local tid = find_thread_for_frame(self, frame.id)
        if tid then self.stopped_thread_id = tid end
      end
      return orig_frame_set(self, frame)
    end
  end

  if ok_sess and type(Session._step) == "function" then
    local orig_step = Session._step
    Session._step = function(self, step, params)
      recover_stopped_thread_id(self)
      return orig_step(self, step, params)
    end
  end

  local ok_guard, guard = pcall(require, "dap-view.guard")
  if ok_guard and type(guard.expect_stopped) == "function" then
    local orig_guard = guard.expect_stopped
    guard.expect_stopped = function()
      recover_stopped_thread_id(dap_mod.session())
      return orig_guard()
    end
  end

  if type(dap_mod.continue) == "function" then
    local orig_continue = dap_mod.continue
    dap_mod.continue = function(opts)
      recover_stopped_thread_id(dap_mod.session())
      return orig_continue(opts)
    end
  end
end

function M.register_diag_command()
  vim.api.nvim_create_user_command("DapThreadDiag", function()
    local session = require("dap").session()
    if not session then
      vim.notify("No active DAP session", vim.log.levels.WARN)
      return
    end
    local info = {
      stopped_thread_id = session.stopped_thread_id,
      current_frame_id  = session.current_frame and session.current_frame.id,
      threads           = {},
    }
    for tid, thread in pairs(session.threads or {}) do
      info.threads[tid] = {
        id           = thread.id,
        name         = thread.name,
        stopped      = thread.stopped,
        frames_count = thread.frames and #thread.frames or 0,
      }
    end
    vim.notify(vim.inspect(info), vim.log.levels.INFO)
  end, { desc = "DAP: Dump thread/session state for diagnostics" })
end

return M
