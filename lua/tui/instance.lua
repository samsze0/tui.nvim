local Controller = require("tui.controller")
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local tbl_utils = require("utils.table")

local M = {}

-- A trait. Should not be inherited directly.
--
---@class TUIInstance : TUIController
---@field layout TUILayout
local Instance = {}
Instance.__index = Instance
Instance.__is_class = true
setmetatable(Instance, { __index = Controller })

-- Configure controller UI hooks
function Instance:_setup_controller_ui_hooks()
  self:set_ui_hooks({
    show = function() self.layout:show() end,
    hide = function() self.layout:hide() end,
    focus = function() self.layout.main_popup:focus() end,
    destroy = function() self.layout:unmount() end,
  })
end

return Instance
