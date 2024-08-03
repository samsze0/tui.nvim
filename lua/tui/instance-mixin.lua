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
    focus = function()
      local main = self.layout.underlay_popups.main
      if not main then error("Main popup not found") end
      main:focus()
    end,
    destroy = function() end,
  })
end

-- TODO: move to private config
---@param target_popup TUIUnderlayPopup
---@param opts? { force?: boolean }
function TUIInstanceMixin:setup_scroll_keymaps(target_popup, opts)
  opts = opts or {}

  local main = self.layout.underlay_popups.main
  if not main then error("Main popup not found") end

  main:map_remote(
    target_popup,
    "<S-Up>",
    "Scroll preview up",
    { force = opts.force }
  )
  main:map_remote(
    target_popup,
    "<S-Left>",
    "Scroll preview left",
    { force = opts.force }
  )
  main:map_remote(
    target_popup,
    "<S-Down>",
    "Scroll preview down",
    { force = opts.force }
  )
  main:map_remote(
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

  for name, popup in pairs(self.layout.underlay_popups) do
    popup:map("<Esc>", "Close", function() self:hide() end)
  end

  for name, popup in pairs(self.layout.overlay_popups) do
    popup:map("<Esc>", "Close overlay", function()
      if self.layout:get_visible_overlay() ~= popup then
        self:_info("Overlay popup not visible")
        return
      end
      self.layout:hide_overlay()
    end)
  end
end

function TUIInstanceMixin:_info(...) self._config.value.notifier.info(...) end

function TUIInstanceMixin:_warn(...) self._config.value.notifier.warn(...) end

function TUIInstanceMixin:_error(...) self._config.value.notifier.error(...) end

return TUIInstanceMixin
