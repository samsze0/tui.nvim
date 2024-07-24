local NuiLayout = require("nui.layout")
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local match = lang_utils.match
local tbl_utils = require("utils.table")
local oop_utils = require("utils.oop")
local TUIMainPopup = require("tui.popup").MainPopup
local TUISidePopup = require("tui.popup").SidePopup
local TUIOverlayPopup = require("tui.popup").OverlayPopup
local TUIHelpPopup = require("tui.popup").HelpPopup

---@type nui_layout_options
local layout_opts = {
  position = "50%",
  relative = "editor",
  size = {
    width = "95%",
    height = "95%",
  },
}

---@alias TUILayout.box_fn fun(): NuiLayout.Box

---@class TUILayout: NuiLayout
---@field _config TUIConfig
---@field main_popup TUIMainPopup
---@field side_popups table<string, TUISidePopup>
---@field overlay_popups table<string, TUIOverlayPopup>
---@field _box_fn TUILayout.box_fn
local TUILayout = oop_utils.new_class(NuiLayout)

---@class TUILayout.constructor.opts
---@field layout_opts? nui_layout_options
---@field config? TUIConfig
---@field box_fn TUILayout.box_fn
---@field main_popup TUIMainPopup
---@field side_popups TUISidePopup[]
---@field other_overlay_popups table<string, TUIOverlayPopup>
---@field help_popup? TUIHelpPopup

---@param opts TUILayout.constructor.opts
---@return TUILayout
function TUILayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_opts = layout_opts,
  }, opts)
  ---@cast opts TUILayout.constructor.opts

  local initial_layout = opts.box_fn()
  local obj = NuiLayout(opts.layout_opts, initial_layout)
  setmetatable(obj, TUILayout)
  ---@cast obj TUILayout

  obj._config = opts.config
  obj._box_fn = opts.box_fn
  obj.main_popup = opts.main_popup
  obj.side_popups = opts.side_popups or {}
  obj.overlay_popups = opts.other_overlay_popups or {}
  obj.overlay_popups["help"] = opts.help_popup

  obj:_setup_move_keymaps()
  obj:_setup_maximise_keymaps()
  obj:_setup_overlay_keymaps()

  return obj
end

---@return (TUIMainPopup | TUISidePopup)[]
function TUILayout:get_main_and_side_popups()
  return {
    self.main_popup,
    unpack(tbl_utils.values(self.side_popups)),
  }
end

---@return TUIPopup[]
function TUILayout:get_all_popups()
  return {
    self.main_popup,
    unpack(tbl_utils.values(self.side_popups)),
    unpack(tbl_utils.values(self.overlay_popups)),
  }
end

function TUILayout:restore()
  for _, popup in ipairs(self:get_main_and_side_popups()) do
    popup.visible = true
  end

  for _, popup in ipairs(self.overlay_popups) do
    popup.visible = false
  end

  self:update(self._box_fn())
end

---@param popup TUIMainPopup | TUISidePopup
---@param opts? { toggle?: boolean, hide_overlay?: boolean }
function TUILayout:maximise_popup(popup, opts)
  opts = opts or {}

  -- Check if popup is a MainPopup or SidePopup
  if
    not oop_utils.is_instance(popup, TUIMainPopup)
    or not oop_utils.is_instance(popup, TUISidePopup)
  then
    error("Popup is not a MainPopup or SidePopup")
  end

  -- Check if popup belongs to layout
  local main_and_side_popups = self:get_main_and_side_popups()
  if
    not tbl_utils.any(
      main_and_side_popups,
      function(_, p) return p == popup end
    )
  then
    error("Popup does not belong to layout")
  end

  -- Check if any main or side popup is maximised, if so, check if it's the same popup
  if opts.toggle then
    local maximised_popup = self:get_maximised_popup()
    if maximised_popup == popup then
      for _, p in ipairs(main_and_side_popups) do
        p.visible = true
      end
      self:update(self._box_fn())
      for _, p in ipairs(main_and_side_popups) do
        p.top_border_text:render()
        p.bottom_border_text:render()
      end
      return
    end
  end

  if opts.hide_overlay then
    for _, p in ipairs(self.overlay_popups) do
      p.visible = false
    end
  end

  for _, p in ipairs(main_and_side_popups) do
    p.visible = false
  end
  popup.visible = true

  self:update(self._box_fn())

  -- Re-render borders because size changed
  -- TODO: only need to re-render the borders of the maximised popup
  for _, p in ipairs(main_and_side_popups) do
    p.top_border_text:render()
    p.bottom_border_text:render()
  end
end

---@param popup TUIOverlayPopup
---@param opts? { toggle?: boolean }
function TUILayout:show_overlay_popup(popup, opts)
  opts = opts or {}

  if not oop_utils.is_instance(popup, TUIOverlayPopup) then
    error("Popup is not an OverlayPopup")
  end

  if not tbl_utils.contains(tbl_utils.values(self.overlay_popups), popup) then
    error("Popup does not belong to layout")
  end

  -- Check if any overlay popup is visible, if so, check if it's the same popup
  if opts.toggle then
    local visible_overlay_popup = self:get_visible_overlay_popup()
    if visible_overlay_popup == popup then
      popup:hide()
      -- TODO: store a field `prev_focused_popup` in TUILayout to restore focus
      local maximised_popup = self:get_maximised_popup()
      if maximised_popup then
        maximised_popup:focus()
      else
        self.main_popup:focus()
      end
      return
    end
  end

  for _, p in pairs(self.overlay_popups) do
    if p:is_visible() then p:hide() end
  end
  popup:show()
  popup:focus()

  popup.top_border_text:render()
  popup.bottom_border_text:render()
end

-- Return the maximised popup if there is one, otherwise return nil
--
---@return (TUIMainPopup | TUISidePopup)?
function TUILayout:get_maximised_popup()
  local main_and_side_popups = self:get_main_and_side_popups()
  local maximised_popups = tbl_utils.filter(
    main_and_side_popups,
    function(_, p) return p.visible end
  )
  if #maximised_popups == 1 then return maximised_popups[1] end
  if #maximised_popups > 1 then error("More than one popups are maximised") end
  return nil
end

-- Return the visible overlay popup if there is one, otherwise return nil
--
---@return TUIOverlayPopup?
function TUILayout:get_visible_overlay_popup()
  local visible_overlay_popups = tbl_utils.filter(
    self.overlay_popups,
    function(_, p) return p:is_visible() end
  )
  if #visible_overlay_popups == 1 then return visible_overlay_popups[1] end
  if #visible_overlay_popups > 1 then
    error("More than one overlay popups are visible")
  end
  return nil
end

function TUILayout:_setup_move_keymaps()
  local keymaps = self._config.value.keymaps.move_to_pane
  ---@cast keymaps -nil

  for _, popup in ipairs(self:get_main_and_side_popups()) do
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

function TUILayout:_setup_maximise_keymaps()
  local keymaps_config = self._config.value.keymaps
  ---@cast keymaps_config -nil

  for _, popup in ipairs(self:get_main_and_side_popups()) do
    popup:map(
      keymaps_config.toggle_maximise,
      "Toggle maximise",
      function() self:maximise_popup(popup, { toggle = true }) end
    )
  end
end

function TUILayout:_setup_overlay_keymaps()
  for _, main_or_side_popup in ipairs(self:get_main_and_side_popups()) do
    for name, overlay_popup in pairs(self.overlay_popups) do
      if oop_utils.is_instance(overlay_popup, TUIHelpPopup) then
        goto continue
      end

      if not overlay_popup._toggle_keymap then
        self._config.value.notifier.warn(
          "Overlay popup " .. name .. " does not have a toggle keymap"
        )
        goto continue
      end

      main_or_side_popup:map(
        overlay_popup._toggle_keymap,
        "Toggle overlay " .. name,
        function() self:show_overlay_popup(overlay_popup, { toggle = true }) end
      )
      ::continue::
    end
  end
end

return TUILayout
