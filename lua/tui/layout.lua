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

  obj:_setup_move_keymaps()
  obj:_setup_maximise_keymaps()

  return obj
end

-- All popups but help_popup
--
---@return TUIPopup[]
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

---@param popup TUIPopup
---@param opts? { toggle?: boolean }
function Layout:maximise_popup(popup, opts)
  opts = opts or {}

  -- Check if popup belongs to layout
  local all_popups = self:all_popups()
  if not tbl_utils.any(all_popups, function(_, p) return p == popup end) then
    error("Popup does not belong to layout")
  end

  -- Check if any popup is maximised, if so, check if it's the same popup
  if opts.toggle then
    local maximised_popups = tbl_utils.filter(
      all_popups,
      function(_, p) return p.should_show end
    )
    if #maximised_popups == 1 and maximised_popups[1] == popup then
      for _, p in ipairs(all_popups) do
        p.should_show = true
      end
      self:update(self._layout_config(self))
      for _, p in ipairs(all_popups) do
        p.top_border_text:render()
        p.bottom_border_text:render()
      end
      return
    end
  end

  for _, p in ipairs(all_popups) do
    p.should_show = false
  end
  popup.should_show = true
  self:update(self._layout_config(self))
  for _, p in ipairs(all_popups) do
    p.top_border_text:render()
    p.bottom_border_text:render()
  end
end

function Layout:_setup_move_keymaps()
  local keymaps = self._config.value.keymaps.move_to_pane
  for _, popup in ipairs(self:all_popups()) do
    for direction, key in pairs(keymaps) do
      popup:map(key, "Move to " .. direction, function()
        local neighbour = popup[direction]
        if neighbour then
          ---@cast neighbour TUIPopup
          neighbour:focus()
        end
      end)
    end
  end
end

function Layout:_setup_maximise_keymaps()
  for _, popup in ipairs(self:all_popups()) do
    popup:map(
      self._config.value.keymaps.toggle_maximise,
      "Toggle maximise",
      function() self:maximise_popup(popup, { toggle = true }) end
    )
  end
end

return Layout
