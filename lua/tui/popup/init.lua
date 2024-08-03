local TUIPopup = require("tui.popup.base")
local TUIOverlayPopup = require("tui.popup.overlay")
local TUIUnderlayPopup = require("tui.popup.underlay")
local TUITUIPopup = require("tui.popup.tui")
local TUIHelpPopup = require("tui.popup.help")

return {
  Base = TUIPopup,
  Overlay = TUIOverlayPopup,
  Underlay = TUIUnderlayPopup,
  TUI = TUITUIPopup,
  Help = TUIHelpPopup,
}
