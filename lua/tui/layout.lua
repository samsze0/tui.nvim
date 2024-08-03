local NuiLayout = require("nui.layout")
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local match = lang_utils.match
local tbl_utils = require("utils.table")
local oop_utils = require("utils.oop")

---@class TUIUnderlayPopupInfo.constructor.opts
---@field visible? boolean
---@field left? TUIUnderlayPopup
---@field right? TUIUnderlayPopup
---@field up? TUIUnderlayPopup
---@field down? TUIUnderlayPopup

---@class TUIUnderlayPopupInfo
---@field visible boolean
---@field left? TUIUnderlayPopup
---@field right? TUIUnderlayPopup
---@field up? TUIUnderlayPopup
---@field down? TUIUnderlayPopup
local TUIUnderlayPopupInfo = oop_utils.new_class()

---@param opts? TUIUnderlayPopupInfo.constructor.opts
---@return TUIUnderlayPopupInfo
function TUIUnderlayPopupInfo.new(opts)
  opts = opts_utils.deep_extend({
    visible = true,
  }, opts)
  ---@cast opts TUIUnderlayPopupInfo.constructor.opts

  local obj = {
    visible = opts.visible,
    left = opts.left,
    right = opts.right,
    up = opts.up,
    down = opts.down,
  }
  setmetatable(obj, TUIUnderlayPopupInfo)
  ---@cast obj TUIUnderlayPopupInfo

  return obj
end

---@class TUIOverlayPopupInfo.constructor.opts
---@field visible? boolean
---@field toggle_keymap string

---@class TUIOverlayPopupInfo
---@field visible boolean
---@field toggle_keymap string
local TUIOverlayPopupInfo = oop_utils.new_class()

---@param opts? TUIOverlayPopupInfo.constructor.opts
---@return TUIOverlayPopupInfo
function TUIOverlayPopupInfo.new(opts)
  opts = opts_utils.deep_extend({
    visible = false,
  }, opts)
  ---@cast opts TUIOverlayPopupInfo.constructor.opts

  local obj = {
    visible = opts.visible,
    toggle_keymap = opts.toggle_keymap,
  }
  setmetatable(obj, TUIOverlayPopupInfo)
  ---@cast obj TUIOverlayPopupInfo

  return obj
end

---@type nui_layout_options
local nui_layout_opts = {
  position = "50%",
  relative = "editor",
  size = {
    width = "95%",
    height = "95%",
  },
}

---@alias TUILayout.box_fn fun(): NuiLayout.Box

---@class TUILayout
---@field _nui_layout NuiLayout
---@field _config TUIConfig
---@field underlay_popups table<string, TUIUnderlayPopup>
---@field overlay_popups table<string, TUIOverlayPopup>
---@field _underlay_popups_info table<string, TUIUnderlayPopupInfo>
---@field _overlay_popups_info table<string, TUIOverlayPopupInfo>
---@field _box_fn TUILayout.box_fn
---@field _prev_win_before_opening_overlay integer? For restoring focus after closing overlay
local TUILayout = oop_utils.new_class(NuiLayout)

---@class TUILayout.constructor.opts
---@field nui_layout_opts? nui_layout_options
---@field config? TUIConfig
---@field box_fn TUILayout.box_fn
---@field underlay_popups table<string, TUIUnderlayPopup>
---@field overlay_popups? table<string, TUIOverlayPopup>
---@field underlay_popups_settings? table<string, TUIUnderlayPopupInfo>
---@field overlay_popups_settings? table<string, TUIOverlayPopupInfo>

---@param opts TUILayout.constructor.opts
---@return TUILayout
function TUILayout.new(opts)
  opts = opts_utils.deep_extend({
    nui_layout_opts = nui_layout_opts,
    overlay_popups = {},
    underlay_popups_settings = {},
    overlay_popups_settings = {},
  }, opts)
  ---@cast opts TUILayout.constructor.opts

  local initial_layout = opts.box_fn()
  local nui_layout = NuiLayout(opts.nui_layout_opts, initial_layout)
  local obj = {}
  setmetatable(obj, TUILayout)
  ---@cast obj TUILayout

  obj._nui_layout = nui_layout
  obj._config = opts.config
  obj._box_fn = opts.box_fn
  obj.underlay_popups = opts.underlay_popups
  for name, p in pairs(opts.underlay_popups) do
    p._name = name
  end
  obj._underlay_popups_info = opts.underlay_popups_settings
  for name, p in pairs(opts.underlay_popups) do
    if not obj._underlay_popups_info[name] then
      obj._underlay_popups_info[name] = TUIUnderlayPopupInfo.new()
    end
  end
  obj.overlay_popups = opts.overlay_popups
  for name, p in pairs(opts.overlay_popups) do
    p._name = name
  end
  obj._overlay_popups_info = opts.overlay_popups_settings
  for name, p in pairs(opts.overlay_popups) do
    if not obj._overlay_popups_info[name] then
      obj._overlay_popups_info[name] = TUIOverlayPopupInfo.new()
    end
  end
  obj._prev_win_before_opening_overlay = nil

  obj:_setup_move_keymaps()
  obj:_setup_maximise_keymaps()
  obj:_setup_overlay_keymaps()

  return obj
end

---@return TUIPopup[]
function TUILayout:get_all_popups()
  return {
    unpack(tbl_utils.values(self.underlay_popups)),
    unpack(tbl_utils.values(self.overlay_popups)),
  }
end

---@param name string
---@return TUIUnderlayPopupInfo
function TUILayout:get_underlay_popup_info(name)
  local info = self._underlay_popups_info[name]
  if not info then error("No info obj found for popup " .. name) end
  return info
end

---@param name string
---@return TUIOverlayPopupInfo
function TUILayout:get_overlay_popup_info(name)
  local info = self._overlay_popups_info[name]
  if not info then error("No info obj found for popup " .. name) end
  return info
end

function TUILayout:restore()
  for name, popup in pairs(self.underlay_popups) do
    self:get_underlay_popup_info(name).visible = true
  end

  for name, popup in pairs(self.overlay_popups) do
    self:get_overlay_popup_info(name).visible = false
  end

  self._nui_layout:update(self._box_fn())
end

-- Maximise an underlay popup
--
---@param popup TUIUnderlayPopup
---@param opts? { toggle?: boolean, hide_overlay?: boolean }
function TUILayout:maximise_popup(popup, opts)
  opts = opts or {}

  -- Check if popup belongs to layout
  if
    not tbl_utils.any(
      self.underlay_popups,
      function(_, p) return p == popup end
    )
  then
    error("Popup does not belong to layout")
  end

  -- Check if any underlay popup is maximised, if so, check if it's the same popup
  if opts.toggle then
    local maximised_popup = self:get_maximised_popup()
    if maximised_popup == popup then
      for name, p in pairs(self.underlay_popups) do
        self:get_underlay_popup_info(name).visible = true
      end
      self._nui_layout:update(self._box_fn())
      for name, p in pairs(self.underlay_popups) do
        p.top_border_text:render()
        p.bottom_border_text:render()
      end
      return
    end
  end

  if opts.hide_overlay then self:hide_overlay() end

  for name, p in pairs(self.underlay_popups) do
    self:get_underlay_popup_info(name).visible = false
  end
  self:get_underlay_popup_info(popup._name).visible = true

  self._nui_layout:update(self._box_fn())

  -- Re-render borders because size changed
  popup.top_border_text:render()
  popup.bottom_border_text:render()
end

---@param popup TUIOverlayPopup
---@param opts? { toggle?: boolean }
function TUILayout:show_overlay_popup(popup, opts)
  opts = opts or {}

  -- TODO
  -- if not oop_utils.is_instance(popup, TUIOverlayPopup) then
  --   error("Popup is not an OverlayPopup")
  -- end

  if not tbl_utils.contains(tbl_utils.values(self.overlay_popups), popup) then
    error("Popup does not belong to layout")
  end

  -- Check if any overlay popup is visible, if so, check if it's the same popup
  if opts.toggle then
    local visible_overlay_popup = self:get_visible_overlay()
    if visible_overlay_popup == popup then
      self:hide_overlay()
      return
    end
  end

  for name, p in pairs(self.overlay_popups) do
    self._overlay_popups_info[name].visible = false
  end
  self._overlay_popups_info[popup._name].visible = true
  self:_update_overlays()

  popup.top_border_text:render()
  popup.bottom_border_text:render()
end

function TUILayout:_update_overlays()
  local overlays_to_show = tbl_utils.values(
    tbl_utils.filter(
      self.overlay_popups,
      function(name, p) return self:get_overlay_popup_info(name).visible end
    )
  )
  ---@cast overlays_to_show TUIOverlayPopup[]
  if #overlays_to_show > 1 then
    error("There can only be one overlay popup visible at a time")
  end

  for _, p in pairs(self.overlay_popups) do
    p._nui_popup:hide()
  end

  if #overlays_to_show == 1 then
    local o = overlays_to_show[1]
    ---@cast o TUIOverlayPopup
    self._prev_win_before_opening_overlay = vim.api.nvim_get_current_win()
    o:show()
    o:focus()
  end
end

-- Return the maximised popup if there is one, otherwise return nil
--
---@return TUIUnderlayPopup?
function TUILayout:get_maximised_popup()
  local visible_popups = tbl_utils.values(
    tbl_utils.filter(
      self.underlay_popups,
      function(name, _) return self:get_underlay_popup_info(name).visible end
    )
  )
  if #visible_popups == 1 then return visible_popups[1] end
  return nil
end

-- Return the visible overlay popup if there is one, otherwise return nil
--
---@return TUIOverlayPopup?
function TUILayout:get_visible_overlay()
  local visible_overlay_popups = tbl_utils.values(
    tbl_utils.filter(
      self.overlay_popups,
      function(name, p) return self:get_overlay_popup_info(name).visible end
    )
  )
  if #visible_overlay_popups == 1 then return visible_overlay_popups[1] end
  if #visible_overlay_popups > 1 then
    error("More than one overlay popups are visible")
  end
  return visible_overlay_popups[1]
end

---@param opts? { }
function TUILayout:hide_overlay(opts)
  -- Check if any overlay is currently visible
  local o = self:get_visible_overlay()
  if not o then return end

  for name, p in pairs(self.overlay_popups) do
    self:get_overlay_popup_info(name).visible = false
  end
  self:_update_overlays()

  local prev_win = self._prev_win_before_opening_overlay
  if not prev_win then error("No prev win prior to opening overlay") end

  -- Check if prev_win is valid
  if not vim.api.nvim_win_is_valid(prev_win) then
    error("Previous win is not valid")
  end

  vim.api.nvim_set_current_win(prev_win)
end

function TUILayout:_setup_move_keymaps()
  local keymaps = self._config.value.keymaps.move_to_pane
  ---@cast keymaps -nil

  for name, popup in pairs(self.underlay_popups) do
    for direction, key in pairs(keymaps) do
      local popup_info = self:get_underlay_popup_info(name)
      popup:map(key, "Move to " .. direction, function()
        local neighbour = popup_info[direction]
        if neighbour then
          ---@cast neighbour TUIPopup
          neighbour:focus()
        end
      end)
    end
  end
end

function TUILayout:_setup_maximise_keymaps()
  local keymaps_config = self._config.value.keymaps
  ---@cast keymaps_config -nil

  for name, popup in pairs(self.underlay_popups) do
    popup:map(
      keymaps_config.toggle_maximise,
      "Toggle maximise",
      function() self:maximise_popup(popup, { toggle = true }) end
    )
  end
end

function TUILayout:_setup_overlay_keymaps()
  for name, overlay_popup in pairs(self.overlay_popups) do
    local popup_info = self:get_overlay_popup_info(name)
    local toggle_keymap = popup_info.toggle_keymap
    if not toggle_keymap then
      self:_warn("Overlay popup " .. name .. " does not have a toggle keymap")
      goto continue
    end

    if name == "help" then goto continue end

    for _, underlay_popup in pairs(self.underlay_popups) do
      underlay_popup:map(
        toggle_keymap,
        "Toggle overlay " .. name,
        function() self:show_overlay_popup(overlay_popup, { toggle = true }) end
      )
    end

    overlay_popup:map(
      toggle_keymap,
      "Hide overlay",
      function() self:hide_overlay() end
    )

    ::continue::
  end
end

function TUILayout:_info(...) self._config.value.notifier.info(...) end

function TUILayout:_warn(...) self._config.value.notifier.warn(...) end

function TUILayout:_error(...) self._config.value.notifier.error(...) end

function TUILayout:mount() self._nui_layout:mount() end

function TUILayout:show() self._nui_layout:show() end

function TUILayout:hide() self._nui_layout:hide() end

return {
  Layout = TUILayout,
  UnderlayPopupSettings = TUIUnderlayPopupInfo,
  OverlayPopupSettings = TUIOverlayPopupInfo,
}
