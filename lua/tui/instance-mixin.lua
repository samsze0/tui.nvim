local TUIController = require("tui.controller")
local oop_utils = require("utils.oop")
local tbl_utils = require("utils.table")

-- A mixin. Should not be inherited directly.
--
---@class TUIInstanceMixin : TUIController
---@field layout TUILayout
local TUIInstanceMixin = oop_utils.new_class(TUIController)

-- Configure controller UI hooks
function TUIInstanceMixin:setup_controller_ui_hooks()
  self:set_ui_hooks({
    show = function() self.layout:show() end,
    hide = function() self.layout:hide() end,
    focus = function() self.layout.main_popup:focus() end,
    destroy = function() end,
  })
end

-- TODO: move to private config
---@param target_popup TUISidePopup
---@param opts? { force?: boolean }
function TUIInstanceMixin:setup_scroll_keymaps(target_popup, opts)
  opts = opts or {}

  self.layout.main_popup:map_remote(
    target_popup,
    "<S-Up>",
    "Scroll preview up",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "<S-Left>",
    "Scroll preview left",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "<S-Down>",
    "Scroll preview down",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "<S-Right>",
    "Scroll preview right",
    { force = opts.force }
  )
end

-- TODO: move to private config
---@param opts? { force?: boolean }
function TUIInstanceMixin:setup_close_keymaps(opts)
  opts = opts or {}

  for _, popup in ipairs(tbl_utils.values(self.layout.side_popups)) do
    ---@cast popup TUISidePopup
    popup:map("<Esc>", "Close", function()
      self:hide()
    end)
  end
end

return TUIInstanceMixin
