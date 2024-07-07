local Controller = require("tui.controller").Controller
local SinglePaneLayout = require("tui.layout").SinglePaneLayout
local DualPaneLayout = require("tui.layout").DualPaneLayout
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")

local M = {}

---@class TUIInstance : TUIController
---@field layout TUILayout
local Instance = {}
Instance.__index = Instance
Instance.__is_class = true
setmetatable(Instance, { __index = Controller })

M.Instance = Instance

---@class TUICreateInstanceOptions : TUICreateControllerOptions

---@param opts? TUICreateInstanceOptions
---@return TUIInstance
function Instance.new(opts)
  local obj = Controller.new(opts)
  setmetatable(obj, Instance)
  ---@cast obj TUIInstance
  return obj
end

-- Configure controller UI hooks
function Instance:_setup_controller_ui_hooks()
  self:set_ui_hooks({
    show = function() self.layout:show() end,
    hide = function() self.layout:hide() end,
    focus = function() self.layout.main_popup:focus() end,
    destroy = function() self.layout:unmount() end,
  })
end

---@class TUIBasicInstance: TUIInstance
---@field layout TUISinglePaneLayout
local BasicInstance = {}
BasicInstance.__index = BasicInstance
BasicInstance.__is_class = true
setmetatable(BasicInstance, { __index = Instance })

M.BasicInstance = BasicInstance

---@param opts? TUICreateInstanceOptions
---@return TUIBasicInstance
function BasicInstance.new(opts)
  local obj = Instance.new(opts)
  setmetatable(obj, BasicInstance)
  ---@cast obj TUIBasicInstance

  local layout = SinglePaneLayout.new({})
  obj.layout = layout

  Instance._setup_controller_ui_hooks(obj)

  return obj
end

return M
