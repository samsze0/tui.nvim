local uuid_utils = require("utils.uuid")
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local CallbackMap = require("tui.callback-map")
local terminal_utils = require("utils.terminal")
local str_utils = require("utils.string")

local M = {}

---@alias TUIControllerId string
---@alias TUIUIHooks { show: function, hide: function, focus: function, destroy: function }
---@alias TUIFocusedEntry any

---@class TUIController
---@field _id TUIControllerId The id of the controller
---@field _index TUIControllersIndex Index of the controllers
---@field _config TUIConfig Configuration of the plugin
---@field focus? TUIFocusedEntry The currently focused entry
---@field _extra_args? ShellOpts Extra arguments to pass to tui
---@field _ui_hooks? TUIUIHooks UI hooks
---@field _extra_env_vars? ShellOpts Extra environment variables to pass to tui
---@field _prev_win? integer Previous window before opening tui
---@field _on_exited_subscribers TUICallbackMap Map of subscribers of the exit event
---@field status "pending" | "started" | "running" | "exited" The status of the controller
---@field _job_id string Job ID of the tui process
local Controller = {}
Controller.__index = Controller
Controller.__is_class = true

-- Index of active controllers
--
---@class TUIControllersIndex
---@field _id_map table<TUIControllerId, TUIController>
---@field most_recent? TUIController
local ControllersIndex = {}
ControllersIndex.__index = ControllersIndex
ControllersIndex.__is_class = true

function ControllersIndex:new()
  return setmetatable({
    _id_map = {},
    most_recent = nil,
  }, ControllersIndex)
end

-- Retrieve a controller by its ID
--
---@param id TUIControllerId
---@return TUIController | nil
function ControllersIndex:get(id) return self._id_map[id] end

-- Remove a controller by its ID
--
---@param id TUIControllerId
function ControllersIndex:remove(id)
  local controller = self:get(id)
  self._id_map[id] = nil

  if self.most_recent == controller then self.most_recent = nil end
end

-- Add a controller to the index
--
---@param controller TUIController
function ControllersIndex:add(controller)
  self._id_map[controller._id] = controller
end

M.ControllersIndex = ControllersIndex

M.Controller = Controller

---@class TUICreateControllerOptions
---@field extra_args? ShellOpts
---@field extra_env_vars? ShellOpts
---@field index? TUIControllersIndex
---@field config? TUIConfig

-- Create controller
--
---@param opts? TUICreateControllerOptions
---@return TUIController
function Controller.new(opts)
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
    _on_exited_subscribers = CallbackMap.new(),
    _prev_win = vim.api.nvim_get_current_win(),
    _status = "pending",
  }
  setmetatable(controller, Controller)
  opts.index:add(controller)

  ---@cast controller TUIController

  return controller
end

-- Destroy controller
function Controller:_destroy()
  self._ui_hooks:destroy()

  self._index:remove(self._id)
end

-- Retrieve prev window (before opening tui)
--
---@return integer
function Controller:prev_win() return self._prev_win end

-- Retrieve prev buffer (before opening tui)
--
---@return integer
function Controller:prev_buf()
  local win = self:prev_win()
  return vim.api.nvim_win_get_buf(win)
end

-- Retrieve the filepath of the file opened in prev buffer (before opening tui)
--
---@return string
function Controller:prev_filepath()
  return vim.api.nvim_buf_get_name(self:prev_buf())
end

-- Retrieve prev tab (before opening tui)
--
---@return integer
function Controller:prev_tab()
  return vim.api.nvim_win_get_tabpage(self:prev_win())
end

-- Show the UI and focus on it
function Controller:show_and_focus()
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
function Controller:hide(opts)
  opts = opts_utils.extend({ restore_focus = true }, opts)

  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.hide()

  if opts.restore_focus then vim.api.nvim_set_current_win(self:prev_win()) end
end

---@param hooks TUIUIHooks
function Controller:set_ui_hooks(hooks) self._ui_hooks = hooks end

-- Start the tui process
function Controller:start() error("Not implemented") end

---@param args ShellOpts
function Controller:_args_extend(args)
  args = tbl_utils.tbl_extend(
    { mode = "error" },
    args,
    self._config.value.default_extra_args
  )
  args = tbl_utils.tbl_extend({ mode = "error" }, args, self._extra_args)

  return args
end

---@param env_vars ShellOpts
function Controller:_env_vars_extend(env_vars)
  env_vars = tbl_utils.tbl_extend(
    { mode = "error" },
    env_vars,
    self._config.value.default_extra_env_vars
  )
  env_vars =
    tbl_utils.tbl_extend({ mode = "error" }, env_vars, self._extra_env_vars)

  return env_vars
end

---@param opts { command: string, hooks: { before_start: function, after_start: function } }
function Controller:_start(opts)
  self:show_and_focus()

  opts.hooks.before_start()

  local job_id = vim.fn.termopen(opts.command, {
    on_exit = function(job_id, code, event)
      self.status = "exited"
      self._on_exited_subscribers:invoke_all()

      if code == 0 then
        -- Pass
      else
        error("Unexpected exit code: " .. code)
      end

      self:_destroy()
    end,
    on_stdout = function(job_id, ...) end,
    on_stderr = function(job_id, ...) end,
  })
  if job_id == 0 or job_id == -1 then error("Failed to start tui app") end
  self._job_id = job_id

  self.status = "running"

  opts.hooks.after_start()
end

-- Send a message to the running tui instance
--
---@param payload any
function Controller:send(payload) error("Not implemented") end

-- Subscribe to tui event
--
---@param event string
---@param callback TUICallback
---@return fun(): nil Unsubscribe
function Controller:subscribe(event, callback) error("Not implemented") end

function Controller:started() return self.status == "started" end

function Controller:exited() return self.status == "exited" end

-- Subscribe to the event "exited"
--
---@param callback fun()
---@return fun() Unsubscribe
function Controller:on_exited(callback)
  return self._on_exited_subscribers:add_and_return_remove_fn(callback)
end

return M
