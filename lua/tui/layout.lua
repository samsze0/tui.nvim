local NuiLayout = require("nui.layout")
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local match = lang_utils.match
local tbl_utils = require("utils.table")

---@type nui_layout_options
local layout_opts = {
  position = "50%",
  relative = "editor",
  size = {
    width = "95%",
    height = "95%",
  },
}

---@alias TUILayout.layout_config fun(layout: TUILayout): NuiLayout.Box

---@class TUILayout: NuiLayout
---@field _config TUIConfig
---@field main_popup TUIMainPopup
---@field side_popups table<string, TUISidePopup>
---@field help_popup TUIHelpPopup
---@field maximise_popup fun(self: TUILayout, popup: TUIPopup)
---@field restore fun(self: TUILayout)
---@field _layout_config TUILayout.layout_config
local Layout = {}
Layout.__index = Layout
Layout.__is_class = true
setmetatable(Layout, { __index = NuiLayout })

---@param opts { layout_opts?: nui_layout_options, config: TUIConfig, layout_config: TUILayout.layout_config, main_popup: TUIMainPopup, side_popups: TUISidePopup[], help_popup: TUIHelpPopup }
---@return TUILayout
function Layout.new(opts)
  opts = opts_utils.deep_extend({
    layout_opts = layout_opts,
  }, opts)

  local initial_layout = opts.layout_config({
    main_popup = opts.main_popup,
    side_popups = opts.side_popups,
    help_popup = opts.help_popup,
  })
  local obj = NuiLayout(opts.layout_opts, initial_layout)
  setmetatable(obj, Layout)
  ---@cast obj TUILayout

  obj._config = opts.config
  obj._layout_config = opts.layout_config
  obj.main_popup = opts.main_popup
  obj.side_popups = opts.side_popups
  obj.help_popup = opts.help_popup

  return obj
end

-- All popups but help_popup
function Layout:all_popups()
  return {
    self.main_popup,
    unpack(tbl_utils.values(self.side_popups)),
  }
end

function Layout:restore()
  for _, popup in ipairs(self:all_popups()) do
    popup.should_show = true
  end

  self:update(self._layout_config(self))
end

-- TODO: move isinstance function to oop utils
local function is_instance(o, class)
  while o do
    o = getmetatable(o)
    if class == o then return true end
  end
  return false
end

---@param popup TUIPopup
function Layout:maximise_popup(popup)
  -- Check if popup belongs to layout
  local all_popups = self:all_popups()
  if not tbl_utils.any(all_popups, function(_, p) return p == popup end) then
    error("Popup does not belong to layout")
  end

  for _, p in ipairs(all_popups) do
    p.should_show = false
  end
  popup.should_show = true
  self:update(self._layout_config(self))
end

return Layout
