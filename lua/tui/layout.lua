local NuiLayout = require("nui.layout")
local MainPopup = require("tui.popup").MainPopup
local SidePopup = require("tui.popup").SidePopup
local HelpPopup = require("tui.popup").HelpPopup
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local match = lang_utils.match

---@type nui_layout_options
local layout_opts = {
  position = "50%",
  relative = "editor",
  size = {
    width = "95%",
    height = "95%",
  },
}

---@class TUILayout: NuiLayout
---@field _config TUIConfig
---@field maximised_popup? TUIPopup
---@field layout_config { default: NuiLayout.Box }
---@field main_popup TUIMainPopup
---@field help_popup TUIHelpPopup
---@field maximise_popup fun(self: TUILayout, popup_name: string)
---@field restore_layout fun(self: TUILayout)
local Layout = {}
Layout.__index = Layout
Layout.__is_class = true
setmetatable(Layout, { __index = NuiLayout })

---@param box NuiLayout.Box
---@param opts? { layout_opts?: nui_layout_options, config?: TUIConfig }
---@return TUILayout
function Layout.new(box, opts)
  opts = opts_utils.deep_extend({
    layout_opts = layout_opts,
  }, opts)

  local obj = NuiLayout(opts.layout_opts, box)
  setmetatable(obj, Layout)
  ---@cast obj TUILayout

  obj._config = opts.config
  obj.maximised_popup = nil

  return obj
end

function Layout:_setup_keymaps()
  -- TODO: uncomment this once "help" feature is ready
  -- self.main_popup:map(config.keymaps.show_help, "Show help", function()
  --   self.help_popup:show()
  --   self.help_popup:focus()
  -- end)
  --
  -- self.help_popup:map(
  --   "n",
  --   config.keymaps.hide_help,
  --   function() self.help_popup:hide() end
  -- )
end

function Layout:restore_layout()
  if self.maximised_popup then
    self:update(self.layout_config.default)
    self.maximised_popup = nil
  end
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
---@param maximised_layout NuiLayout.Box
function Layout:_maximise_popup(popup, maximised_layout)
  local fn = function()
    if self.maximised_popup == popup then
      self:update(self.layout_config.default)
      self.maximised_popup = nil
    else
      self:update(maximised_layout)
      self.maximised_popup = popup
    end
  end

  fn()

  -- Potentially in the future we might want to inject these methods directly into popups instead
  -- if is_instance(popup, MainPopup) then
  --   ---@cast popup TUIMainPopup
  --   popup:map(config.keymaps.toggle_maximise, "Toggle maximise", fn)
  -- else
  --   popup:map("n", config.keymaps.toggle_maximise, fn)
  -- end
end

-- TODO: remove need to declare something like layout_config. Layout should be derived automatically using something like CSS flexbox (flex grow, shrink, ratio, etc)

---@class TUISinglePaneLayout: TUILayout
---@field main_popup TUIMainPopup
---@field help_popup TUIHelpPopup
local SinglePaneLayout = {}
SinglePaneLayout.__index = SinglePaneLayout
SinglePaneLayout.__is_class = true
setmetatable(SinglePaneLayout, { __index = Layout })

---@class TUICreateSinglePaneLayoutOptions
---@field main_popup? TUIMainPopup
---@field help_popup? TUIHelpPopup
---@field extra_layout_opts? nui_layout_options
---@field layout_config? { default?: fun(main_popup: TUIMainPopup, help_popup: TUIHelpPopup): NuiLayout.Box }
---@field config? TUIConfig

---@param opts? TUICreateSinglePaneLayoutOptions
---@return TUISinglePaneLayout
function SinglePaneLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "100%" }),
        }, {})
      end,
    },
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(opts.main_popup, opts.help_popup),
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, SinglePaneLayout)
  ---@cast obj TUISinglePaneLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.help_popup = opts.help_popup

  obj:_setup_keymaps()

  return obj
end

function SinglePaneLayout:_setup_keymaps() Layout._setup_keymaps(self) end

---@class TUIDualPaneLayout: TUILayout
---@field layout_config { default?: NuiLayout.Box, maximised?: { main: NuiLayout.Box, side: NuiLayout.Box } }
---@field side_popup TUISidePopup
local DualPaneLayout = {}
DualPaneLayout.__index = DualPaneLayout
DualPaneLayout.__is_class = true
setmetatable(DualPaneLayout, { __index = Layout })

---@alias TUICreateDualPaneLayoutOptions.layout_config.fn fun(main_popup: TUIMainPopup, side_popup: TUISidePopup, help_popup: TUIHelpPopup): NuiLayout.Box

---@class TUICreateDualPaneLayoutOptions.layout_config.maximised
---@field main TUICreateDualPaneLayoutOptions.layout_config.fn
---@field side TUICreateDualPaneLayoutOptions.layout_config.fn

---@class TUICreateDualPaneLayoutOptions.layout_config
---@field default TUICreateDualPaneLayoutOptions.layout_config.fn
---@field maximised TUICreateDualPaneLayoutOptions.layout_config.maximised

---@class TUICreateDualPaneLayoutOptions
---@field main_popup? TUIMainPopup
---@field side_popup? TUISidePopup
---@field help_popup? TUIHelpPopup
---@field extra_layout_opts? nui_layout_options
---@field layout_config? TUICreateDualPaneLayoutOptions.layout_config
---@field config? TUIConfig

---@param opts? TUICreateDualPaneLayoutOptions
---@return TUIDualPaneLayout
function DualPaneLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, side_popup, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "50%" }),
          NuiLayout.Box(side_popup, { size = "50%" }),
        }, { dir = "row" })
      end,
      maximised = {
        main = function(main_popup, side_popup, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(main_popup, { size = "100%" }),
          }, {})
        end,
        side = function(main_popup, side_popup, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(side_popup, { size = "100%" }),
          }, {})
        end,
      },
    },
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  if not opts.side_popup then opts.side_popup = SidePopup.new() end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(
      opts.main_popup,
      opts.side_popup,
      opts.help_popup
    ),
    maximised = {
      main = opts.layout_config.maximised.main(
        opts.main_popup,
        opts.side_popup,
        opts.help_popup
      ),
      side = opts.layout_config.maximised.side(
        opts.main_popup,
        opts.side_popup,
        opts.help_popup
      ),
    },
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, DualPaneLayout)
  ---@cast obj TUIDualPaneLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.side_popup = opts.side_popup
  obj.help_popup = opts.help_popup

  obj:_setup_keymaps()

  return obj
end

function DualPaneLayout:_setup_keymaps()
  Layout._setup_keymaps(self)

  self.main_popup:map(
    self._config.value.keymaps.move_to_pane.right,
    "Move to side pane",
    function() self.side_popup:focus() end
  )

  self.side_popup:map(
    "n",
    self._config.value.keymaps.move_to_pane.left,
    function() self.main_popup:focus() end
  )
end

---@param popup_name "main" | "side"
function DualPaneLayout:maximise_popup(popup_name)
  local popup = match(popup_name, {
    ["main"] = self.main_popup,
    ["side"] = self.side_popup,
  })
  local maximised_layout = match(popup_name, {
    ["main"] = self.layout_config.maximised.main,
    ["side"] = self.layout_config.maximised.side,
  })

  Layout._maximise_popup(self, popup, maximised_layout)
end

---@class TUITriplePaneLayout: TUILayout
---@field layout_config { default?: NuiLayout.Box, maximised?: { main: NuiLayout.Box, side: { left: NuiLayout.Box, right: NuiLayout.Box } } }
---@field side_popups { left: TUISidePopup, right: TUISidePopup }
local TriplePaneLayout = {}
TriplePaneLayout.__index = TriplePaneLayout
TriplePaneLayout.__is_class = true
setmetatable(TriplePaneLayout, { __index = Layout })

---@alias TUICreateTriplePaneLayoutOptions.layout_config.fn fun(main_popup: TUIMainPopup, side_popups: { left: TUISidePopup, right: TUISidePopup }, help_popup: TUIHelpPopup): NuiLayout.Box

---@class TUICreateTriplePaneLayoutOptions.layout_config.maximised
---@field main? TUICreateTriplePaneLayoutOptions.layout_config.fn
---@field side? { left?: TUICreateTriplePaneLayoutOptions.layout_config.fn, right?: TUICreateTriplePaneLayoutOptions.layout_config.fn }

---@class TUICreateTriplePaneLayoutOptions.layout_config
---@field default? TUICreateTriplePaneLayoutOptions.layout_config.fn
---@field maximised? TUICreateTriplePaneLayoutOptions.layout_config.maximised

---@class TUICreateTriplePaneLayoutOptions
---@field main_popup? TUIMainPopup
---@field side_popups? { left: TUISidePopup, right: TUISidePopup }
---@field help_popup? TUIHelpPopup
---@field extra_layout_opts? nui_layout_options
---@field layout_config? TUICreateTriplePaneLayoutOptions.layout_config
---@field config? TUIConfig

---@param opts? TUICreateTriplePaneLayoutOptions
---@return TUITriplePaneLayout
function TriplePaneLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, side_popups, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "30%" }),
          NuiLayout.Box(side_popups.left, { size = "35%" }),
          NuiLayout.Box(side_popups.right, { size = "35%" }),
        }, { dir = "row" })
      end,
      maximised = {
        main = function(main_popup, side_popups, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(main_popup, { size = "100%" }),
          }, {})
        end,
        side = {
          left = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.left, { size = "100%" }),
            }, {})
          end,
          right = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.right, { size = "100%" }),
            }, {})
          end,
        },
      },
    },
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  -- TODO
  if not opts.side_popups then
    opts.side_popups = {
      left = SidePopup.new(),
      right = SidePopup.new(),
    }
  end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(
      opts.main_popup,
      opts.side_popups,
      opts.help_popup
    ),
    maximised = {
      main = opts.layout_config.maximised.main(
        opts.main_popup,
        opts.side_popups,
        opts.help_popup
      ),
      side = {
        left = opts.layout_config.maximised.side.left(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
        right = opts.layout_config.maximised.side.right(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
      },
    },
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, TriplePaneLayout)
  ---@cast obj TUITriplePaneLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.side_popups = opts.side_popups
  obj.help_popup = opts.help_popup

  obj:_setup_keymaps()

  return obj
end

function TriplePaneLayout:_setup_keymaps()
  Layout._setup_keymaps(self)

  self.main_popup:map(
    self._config.value.keymaps.move_to_pane.right,
    "Move to side pane",
    function() self.side_popups.left:focus() end
  )

  self.side_popups.left:map(
    "n",
    self._config.value.keymaps.move_to_pane.left,
    function() self.main_popup:focus() end
  )

  self.side_popups.left:map(
    "n",
    self._config.value.keymaps.move_to_pane.right,
    function() self.side_popups.right:focus() end
  )

  self.side_popups.right:map(
    "n",
    self._config.value.keymaps.move_to_pane.left,
    function() self.side_popups.left:focus() end
  )
end

---@param popup_name "main" | "side-left" | "side-right"
function TriplePaneLayout:maximise_popup(popup_name)
  local popup = match(popup_name, {
    ["main"] = self.main_popup,
    ["side-left"] = self.side_popups.left,
    ["side-right"] = self.side_popups.right,
  })
  local maximised_layout = match(popup_name, {
    ["main"] = self.layout_config.maximised.main,
    ["side-left"] = self.layout_config.maximised.side.left,
    ["side-right"] = self.layout_config.maximised.side.right,
  })

  Layout._maximise_popup(self, popup, maximised_layout)
end

---@class TUITriplePane2ColumnLayout: TUILayout
---@field layout_config { default?: NuiLayout.Box, maximised?: { main: NuiLayout.Box, side: { top: NuiLayout.Box, bottom: NuiLayout.Box } } }
---@field side_popups { top: TUISidePopup, bottom: TUISidePopup }
local TriplePane2ColumnLayout = {}
TriplePane2ColumnLayout.__index = TriplePane2ColumnLayout
TriplePane2ColumnLayout.__is_class = true
setmetatable(TriplePane2ColumnLayout, { __index = Layout })

---@alias TUICreateTriplePane2ColumnLayoutOptions.layout_config.fn fun(main_popup: TUIMainPopup, side_popups: { top: TUISidePopup, bottom: TUISidePopup }, help_popup: TUIHelpPopup): NuiLayout.Box

---@class TUICreateTriplePane2ColumnLayoutOptions.layout_config.maximised
---@field main? TUICreateTriplePane2ColumnLayoutOptions.layout_config.fn
---@field side? { top?: TUICreateTriplePane2ColumnLayoutOptions.layout_config.fn, bottom?: TUICreateTriplePane2ColumnLayoutOptions.layout_config.fn }

---@class TUICreateTriplePane2ColumnLayoutOptions.layout_config
---@field default? TUICreateTriplePane2ColumnLayoutOptions.layout_config.fn
---@field maximised? TUICreateTriplePane2ColumnLayoutOptions.layout_config.maximised

---@class TUICreateTriplePane2ColumnLayoutOptions
---@field main_popup? TUIMainPopup
---@field side_popups? { top: TUISidePopup, bottom: TUISidePopup }
---@field help_popup? TUIHelpPopup
---@field extra_layout_opts? nui_layout_options
---@field layout_config? TUICreateTriplePane2ColumnLayoutOptions.layout_config
---@field config? TUIConfig

---@param opts? TUICreateTriplePane2ColumnLayoutOptions
---@return TUITriplePane2ColumnLayout
function TriplePane2ColumnLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, side_popups, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "50%" }),
          NuiLayout.Box({
            NuiLayout.Box(side_popups.top, { size = "20%" }),
            NuiLayout.Box(side_popups.bottom, { grow = 1 }),
          }, { size = "50%", dir = "col" }),
        }, { dir = "row" })
      end,
      maximised = {
        main = function(main_popup, side_popups, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(main_popup, { size = "100%" }),
          }, {})
        end,
        side = {
          top = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.top, { size = "100%" }),
            }, {})
          end,
          bottom = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.bottom, { size = "100%" }),
            }, {})
          end,
        },
      },
    },
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  -- TODO
  if not opts.side_popups then
    opts.side_popups = {
      top = SidePopup.new(),
      bottom = SidePopup.new(),
    }
  end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(
      opts.main_popup,
      opts.side_popups,
      opts.help_popup
    ),
    maximised = {
      main = opts.layout_config.maximised.main(
        opts.main_popup,
        opts.side_popups,
        opts.help_popup
      ),
      side = {
        top = opts.layout_config.maximised.side.top(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
        bottom = opts.layout_config.maximised.side.bottom(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
      },
    },
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, TriplePane2ColumnLayout)
  ---@cast obj TUITriplePane2ColumnLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.side_popups = opts.side_popups
  obj.help_popup = opts.help_popup

  obj:_setup_keymaps()

  return obj
end

function TriplePane2ColumnLayout:_setup_keymaps()
  Layout._setup_keymaps(self)

  self.main_popup:map(
    self._config.value.keymaps.move_to_pane.right,
    "Move to side pane",
    function() self.side_popups.top:focus() end
  )

  self.side_popups.top:map(
    "n",
    self._config.value.keymaps.move_to_pane.left,
    function() self.main_popup:focus() end
  )

  self.side_popups.top:map(
    "n",
    self._config.value.keymaps.move_to_pane.down,
    function() self.side_popups.bottom:focus() end
  )

  self.side_popups.bottom:map(
    "n",
    self._config.value.keymaps.move_to_pane.up,
    function() self.side_popups.top:focus() end
  )
end

---@param popup_name "main" | "side-top" | "side-bottom"
function TriplePane2ColumnLayout:maximise_popup(popup_name)
  local popup = match(popup_name, {
    ["main"] = self.main_popup,
    ["side-top"] = self.side_popups.top,
    ["side-bottom"] = self.side_popups.bottom,
  })
  local maximised_layout = match(popup_name, {
    ["main"] = self.layout_config.maximised.main,
    ["side-top"] = self.layout_config.maximised.side.top,
    ["side-bottom"] = self.layout_config.maximised.side.bottom,
  })

  Layout._maximise_popup(self, popup, maximised_layout)
end

return {
  AbstractLayout = Layout,
  SinglePaneLayout = SinglePaneLayout,
  DualPaneLayout = DualPaneLayout,
  TriplePaneLayout = TriplePaneLayout,
  TriplePane2ColumnLayout = TriplePane2ColumnLayout,
}
