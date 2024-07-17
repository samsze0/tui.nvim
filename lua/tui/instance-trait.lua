local TUIController = require("tui.controller")
local oop_utils = require("utils.oop")

-- A trait. Should not be inherited directly.
--
---@class TUIInstanceTrait : TUIController
---@field layout TUILayout
local TUIInstanceTrait = oop_utils.new_class(TUIController)

-- Configure controller UI hooks
function TUIInstanceTrait:setup_controller_ui_hooks()
  self:set_ui_hooks({
    show = function() self.layout:show() end,
    hide = function() self.layout:hide() end,
    focus = function() self.layout.main_popup:focus() end,
    destroy = function() end,
  })
end

return TUIInstanceTrait
