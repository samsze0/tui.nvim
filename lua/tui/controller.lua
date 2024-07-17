local uuid_utils = require("utils.uuid")
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local TUICallbackMap = require("tui.callback-map")
local terminal_utils = require("utils.terminal")
local str_utils = require("utils.string")
local oop_utils = require("utils.oop")

---@alias TUIControllerId string
---@alias TUIUIHooks { show: function, hide: function, focus: function, destroy: function }
---@alias TUIFocusedEntry any

---@class TUIController
---@field _id TUIControllerId The id of the controller
---@field _index TUIControllerMap Index of the controllers
---@field _config TUIConfig Configuration of the plugin
---@field focus? TUIFocusedEntry The currently focused entry
---@field _extra_args? ShellOpts Extra arguments to pass to tui
---@field _ui_hooks? TUIUIHooks UI hooks
---@field _extra_env_vars? ShellOpts Extra environment variables to pass to tui
---@field _prev_win? integer Previous window before opening tui
---@field _on_exited_subscribers TUICallbackMap Map of subscribers of the exit event
---@field status "pending" | "running" | "exited" | "destroyed" The status of the controller
---@field _job_id string Job ID of the tui process
local TUIController = oop_utils.create_class()

---@class TUICreateControllerOptions
---@field extra_args? ShellOpts
---@field extra_env_vars? ShellOpts
---@field index? TUIControllerMap
---@field config? TUIConfig

-- Create controller
--
---@param opts? TUICreateControllerOptions
---@return TUIController
function TUIController.new(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts TUICreateControllerOptions

  local controller_id = uuid_utils.v4()
  local controller = {
    _id = controller_id,
    _index = opts.index,
    _config = opts.config,
    focus = nil,
    _extra_args = opts.extra_args,
    _ui_hooks = nil,
    _extra_env_vars = opts.extra_env_vars,
    _on_exited_subscribers = TUICallbackMap.new(),
    _prev_win = vim.api.nvim_get_current_win(),
    _status = "pending",
  }
  setmetatable(controller, TUIController)

  ---@cast controller TUIController

  return controller
end

-- Destroy controller
function TUIController:_destroy()
  self._ui_hooks:destroy()

  self._index:remove(self._id)

  self._status = "destroyed"
end

-- Retrieve prev window (before opening tui)
--
---@return integer
function TUIController:prev_win() return self._prev_win end

-- Retrieve prev buffer (before opening tui)
--
---@return integer
function TUIController:prev_buf()
  local win = self:prev_win()
  return vim.api.nvim_win_get_buf(win)
end

-- Retrieve the filepath of the file opened in prev buffer (before opening tui)
--
---@return string
function TUIController:prev_filepath()
  return vim.api.nvim_buf_get_name(self:prev_buf())
end

-- Retrieve prev tab (before opening tui)
--
---@return integer
function TUIController:prev_tab()
  return vim.api.nvim_win_get_tabpage(self:prev_win())
end

-- Show the UI and focus on it
function TUIController:show_and_focus()
  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.show()
  self._ui_hooks.focus()

  self._index.most_recent = self
end

-- Hide the UI
--
---@param opts? { restore_focus?: boolean }
function TUIController:hide(opts)
  opts = opts_utils.extend({ restore_focus = true }, opts)

  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.hide()

  if opts.restore_focus then vim.api.nvim_set_current_win(self:prev_win()) end
end

---@param hooks TUIUIHooks
function TUIController:set_ui_hooks(hooks) self._ui_hooks = hooks end

-- Start the tui process
function TUIController:start() error("Not implemented") end

---@param args ShellOpts
function TUIController:_args_extend(args)
  args = tbl_utils.tbl_extend(
    { mode = "error" },
    args,
    self._config.value.default_extra_args
  )
  args = tbl_utils.tbl_extend({ mode = "error" }, args, self._extra_args)

  return args
end

---@param env_vars ShellOpts
function TUIController:_env_vars_extend(env_vars)
  env_vars = tbl_utils.tbl_extend(
    { mode = "error" },
    env_vars,
    self._config.value.default_extra_env_vars
  )
  env_vars =
    tbl_utils.tbl_extend({ mode = "error" }, env_vars, self._extra_env_vars)

  return env_vars
end

---@param opts { command: string, exit_code_handler?: fun(code: integer) }
function TUIController:_start(opts)
  opts = opts_utils.extend({
    exit_code_handler = function(code)
      if code == 0 then
        -- Pass
      else
        error("Unexpected exit code: " .. code)
      end
    end,
  }, opts)

  self:show_and_focus()

  local job_id = vim.fn.termopen(opts.command, {
    on_exit = function(job_id, code, event)
      xpcall(
        function()
          if self.status ~= "running" then return end

          self.status = "exited"
          self._on_exited_subscribers:invoke_all()

          opts.exit_code_handler(code)

          self:_destroy()
        end,
        function(err)
          self._config.value.notifier.error(
            debug.traceback("An error occurred during on_exit: " .. err)
          )
        end
      )
    end,
    on_stdout = function(job_id, ...) end,
    on_stderr = function(job_id, ...) end,
  })
  if job_id == 0 or job_id == -1 then error("Failed to start tui app") end
  self._job_id = job_id

  self.status = "running"

  self._index:add(self)
end

-- Send a message to the running tui instance
--
---@param payload any
function TUIController:send(payload) error("Not implemented") end

-- Subscribe to tui event
--
---@param event string
---@param callback TUICallback
---@return fun(): nil Unsubscribe
function TUIController:subscribe(event, callback) error("Not implemented") end

function TUIController:started() return self.status ~= "pending" end

function TUIController:exited()
  return self.status == "exited" or self.status == "destroyed"
end

-- Subscribe to the event "exited"
--
---@param callback fun()
---@return fun() Unsubscribe
function TUIController:on_exited(callback)
  return self._on_exited_subscribers:add_and_return_remove_fn(callback)
end

return TUIController
