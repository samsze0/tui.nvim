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

---@class TUIUnderlayPopup: TUIPopup
local TUIUnderlayPopup = oop_utils.new_class(TUIPopup)

---@class TUIUnderlayPopup.constructor.opts : TUIPopup.constructor.opts

---@param opts TUIUnderlayPopup.constructor.opts
---@return TUIUnderlayPopup
function TUIUnderlayPopup.new(opts)
  opts = opts_utils.deep_extend({
    popup_opts = {
      buf_options = {
        modifiable = true,
      },
      win_options = {
        number = false,
        wrap = false,
      },
    },
  }, opts)

  local obj = TUIPopup.new(opts)
  setmetatable(obj, TUIUnderlayPopup)
  ---@cast obj TUIUnderlayPopup

  return obj
end

return TUIUnderlayPopup
