local TUIController = require("tui.controller")
local oop_utils = require("utils.oop")
local tbl_utils = require("utils.table")

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

-- TODO: move to private config
---@param target_popup TUISidePopup
---@param opts? { force?: boolean }
function TUIInstanceTrait:setup_scroll_keymaps(target_popup, opts)
  opts = opts or {}

  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview up",
    "<S-Up>",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview left",
    "<S-Left>",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview down",
    "<S-Down>",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview right",
    "<S-Right>",
    { force = opts.force }
  )
end

-- TODO: move to private config
---@param opts? { force?: boolean }
function TUIInstanceTrait:setup_close_keymaps(opts)
  opts = opts or {}

  for _, popup in ipairs(tbl_utils.values(self.layout.side_popups)) do
    ---@cast popup TUISidePopup
    popup:map("<Esc>", "Close", function()
      self:hide()
    end)
  end
end

return TUIInstanceTrait
