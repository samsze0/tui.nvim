local NuiEvent = require("nui.utils.autocmd").event
local opts_utils = require("utils.opts")
local oop_utils = require("utils.oop")
local TUIUnderlayPopup = require("tui.popup.underlay")

---@class TUITUIPopup: TUIUnderlayPopup
local TUITUIPopup = oop_utils.new_class(TUIUnderlayPopup)

---@class TUITUIPopup.constructor.opts : TUIPopup.constructor.opts

---@param opts TUITUIPopup.constructor.opts
---@return TUITUIPopup
function TUITUIPopup.new(opts)
  opts = opts_utils.deep_extend({
    nui_popup_opts = {
      enter = false, -- This can mute BufEnter event
      buf_options = {
        modifiable = false,
        filetype = "tui",
      },
      win_options = {},
    },
  }, opts)

  local obj = TUIUnderlayPopup.new(opts)
  setmetatable(obj, TUITUIPopup)
  ---@cast obj TUITUIPopup

  obj:on(NuiEvent.BufEnter, function() vim.cmd("startinsert!") end)

  return obj
end

---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function TUITUIPopup:map(key, name, handler, opts)
  self:_map("t", key, name, handler, opts)
end

---@param popup TUIUnderlayPopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function TUITUIPopup:map_remote(popup, key, name, opts)
  self:_map_remote("t", popup, key, name, opts)
end

return TUITUIPopup
