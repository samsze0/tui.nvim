local NuiPopup = require("nui.popup")
local NuiEvent = require("nui.utils.autocmd").event
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local file_utils = require("utils.files")
local PopupBorderText = require("tui.popup-border-text")
local winhighlight_utils = require("utils.winhighlight")
local oop_utils = require("utils.oop")
local shared = require("tui.popup.shared")
local TUIPopup = require("tui.popup.base")
local TUIOverlayPopup = require("tui.popup.overlay")

---@class TUIHelpPopup: TUIOverlayPopup
---@fieid private _toggle_keymap any
local TUIHelpPopup = oop_utils.new_class(TUIOverlayPopup)

---@class TUIHelpPopup.constructor.opts : TUIOverlayPopup.constructor.opts

---@param opts TUIHelpPopup.constructor.opts
---@return TUIHelpPopup
function TUIHelpPopup.new(opts)
  opts = opts_utils.deep_extend({}, opts)

  local obj = TUIOverlayPopup.new(opts)
  setmetatable(obj, TUIHelpPopup)
  ---@cast obj TUIHelpPopup

  local title = obj.top_border_text:prepend("left")
  title:render("Help")

  return obj
end

return TUIHelpPopup
