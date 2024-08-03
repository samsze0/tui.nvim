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

---@class TUIOverlayPopup: TUIPopup
local TUIOverlayPopup = oop_utils.new_class(TUIPopup)

---@class TUIOverlayPopup.constructor.opts : TUIPopup.constructor.opts

---@param opts TUIOverlayPopup.constructor.opts
---@return TUIOverlayPopup
function TUIOverlayPopup.new(opts)
  opts = opts_utils.deep_extend({
    popup_opts = {
      win_options = {
        wrap = true,
      },
      relative = "editor",
      position = "50%",
      size = {
        width = "75%",
        height = "75%",
      },
      zindex = shared.OVERLAY_POPUP_Z_INDEX,
    },
  }, opts)

  local obj = TUIPopup.new(opts)
  setmetatable(obj, TUIOverlayPopup)
  ---@cast obj TUIOverlayPopup

  return obj
end

return TUIOverlayPopup
