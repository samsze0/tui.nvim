local NuiPopup = require("nui.popup")
local NuiEvent = require("nui.utils.autocmd").event
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local file_utils = require("utils.files")
local PopupBorderText = require("tui.popup-border-text")
local winhighlight_utils = require("utils.winhighlight")
local oop_utils = require("utils.oop")

---@class TUIPopup: NuiPopup
---@field _config TUIConfig
---@field _tui_keymaps table<string, string> Mappings of key to name (of the handler)
---@field top_border_text TUIPopupBorderText
---@field bottom_border_text TUIPopupBorderText
---@field visible boolean Whether or not the popup is visible within the TUILayout
---@field left? TUIPopup
---@field right? TUIPopup
---@field up? TUIPopup
---@field down? TUIPopup
local TUIPopup = oop_utils.new_class(NuiPopup)

---@class TUIPopup.constructor.opts
---@field popup_opts? nui_popup_options
---@field config TUIConfig

---@param opts TUIPopup.constructor.opts
---@return TUIPopup
function TUIPopup.new(opts)
  local config = opts.config.value

  ---@type nui_popup_options
  local popup_opts = {
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = "", -- Border text would not show if this is undefined
        bottom = "",
      },
    },
    win_options = {
      winblend = 0,
    },
  }

  popup_opts = opts_utils.deep_extend(popup_opts, opts.popup_opts)

  local win_hl = opts_utils.extend({
    Normal = "Normal",
    FloatBorder = config.highlight_groups.border.inactive,
  }, winhighlight_utils.from_str(popup_opts.win_options.winhighlight))

  popup_opts.win_options.winhighlight = winhighlight_utils.to_str(win_hl)

  local obj = NuiPopup(popup_opts)
  setmetatable(obj, TUIPopup)
  ---@cast obj TUIPopup

  obj.visible = true

  obj._tui_keymaps = {}
  obj._config = opts.config
  obj.top_border_text = PopupBorderText.new({
    config = opts.config,
    popup = obj,
  })
  obj.bottom_border_text = PopupBorderText.new({
    config = opts.config,
    popup = obj,
  })

  obj.top_border_text:on_render(
    function(output) obj.border:set_text("top", output, "left") end
  )
  obj.bottom_border_text:on_render(
    function(output) obj.border:set_text("bottom", output, "left") end
  )

  local set_border_hl = function(hl_group) obj.border:set_highlight(hl_group) end

  -- Border highlight control
  obj:on(NuiEvent.BufEnter, function()
    local hl_group = config.highlight_groups.border.active
    ---@cast hl_group string

    set_border_hl(hl_group)
  end)
  obj:on(NuiEvent.BufLeave, function()
    local hl_group = config.highlight_groups.border.inactive
    ---@cast hl_group string

    set_border_hl(hl_group)
  end)

  return obj
end

function TUIPopup:focus() vim.api.nvim_set_current_win(self.winid) end

-- Get current mappings of keys to handler names
--
---@return table<string, string>
function TUIPopup:keymaps() return self._tui_keymaps end

---@class TUIMainPopup: TUIPopup
local TUIMainPopup = oop_utils.new_class(TUIPopup)

---@class TUIMainPopup.constructor.opts : TUIPopup.constructor.opts

---@param opts TUIMainPopup.constructor.opts
---@return TUIMainPopup
function TUIMainPopup.new(opts)
  opts = opts_utils.deep_extend({
    popup_opts = {
      enter = false, -- This can mute BufEnter event
      buf_options = {
        modifiable = false,
        filetype = "tui",
      },
      win_options = {},
    },
  }, opts)

  local obj = TUIPopup.new(opts)
  setmetatable(obj, TUIMainPopup)
  ---@cast obj TUIMainPopup

  obj:on(NuiEvent.BufEnter, function() vim.cmd("startinsert!") end)

  return obj
end

---@class TUISidePopup: TUIPopup
local TUISidePopup = oop_utils.new_class(TUIPopup)

---@class TUISidePopup.constructor.opts : TUIPopup.constructor.opts

---@param opts TUISidePopup.constructor.opts
---@return TUISidePopup
function TUISidePopup.new(opts)
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
  setmetatable(obj, TUISidePopup)
  ---@cast obj TUISidePopup

  return obj
end

---@return string[]
function TUISidePopup:get_lines()
  return vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
end

---@param lines string[]
---@param opts? { cursor_pos?: number[], filetype?: string }
function TUISidePopup:set_lines(lines, opts)
  opts = opts_utils.extend({}, opts)

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  if opts.cursor_pos then
    vim.api.nvim_win_set_cursor(self.winid, opts.cursor_pos or { 1, 0 })
    vim.api.nvim_win_call(self.winid, function() vim.cmd("normal! zz") end)
  end

  vim.bo[self.bufnr].filetype = opts.filetype or ""
end

-- Show the content of a file in the popup
--
-- If file cannot be shown for any reason, it will show an error message instead
--
---@param path string
---@param opts? { cursor_pos?: number[], exclude_filetypes?: string[] }
---@return boolean success
function TUISidePopup:show_file_content(path, opts)
  opts = opts_utils.extend({
    exclude_filetypes = {},
  }, opts)

  self:set_lines({})

  local type = vim.fn.getftype(path)
  if type ~= "file" then
    self:set_lines({ "Not a file" })
    return false
  end

  if vim.fn.filereadable(path) ~= 1 then
    self:set_lines({ "File not readable, or doesnt exist" })
    return false
  end

  local file_size = vim.fn.getfsize(path)
  -- Check if file_size exceeds 1MB
  if file_size > 1024 * 1024 then
    self:set_lines({ "File is too large for preview" })
    return false
  end

  local filetype = file_utils.get_filetype(path)
  if filetype then
    if tbl_utils.contains(opts.exclude_filetypes, filetype) then
      self:set_lines({
        "No preview available for filetype " .. filetype,
      })
      return false
    end
  end

  local is_text = file_utils.is_text(path)
  if not is_text then
    self:set_lines({ "Not a text file" })
    return false
  end

  local lines = file_utils.read_file(path, { binary = true }) -- Read in binary mode to avoid extra CR being trimmed

  self:set_lines(lines, { cursor_pos = opts.cursor_pos })
  vim.bo[self.bufnr].filetype = filetype or ""

  return true
end

---@param buf number
---@param opts? { cursor_pos?: number[] }
function TUISidePopup:show_buf_content(buf, opts)
  opts = opts or {}

  local path = vim.api.nvim_buf_get_name(buf)
  self:show_file_content(path, { cursor_pos = opts.cursor_pos })
end

---@class TUIOverlayPopup: TUISidePopup
---@field private left any
---@field private right any
---@field private up any
---@field private down any
---@field private visible any
---@field _toggle_keymap string
local TUIOverlayPopup = oop_utils.new_class(TUISidePopup)

---@class TUIOverlayPopup.constructor.opts : TUISidePopup.constructor.opts
---@field toggle_keymap string

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
      zindex = 50,
    },
  }, opts)

  local obj = TUISidePopup.new(opts)
  setmetatable(obj, TUIOverlayPopup)
  ---@cast obj TUIOverlayPopup

  obj._toggle_keymap = opts.toggle_keymap

  return obj
end

function TUIOverlayPopup:is_visible() return self.winid ~= nil end

---@class TUIHelpPopup: TUIOverlayPopup
---@fieid private _toggle_keymap any
local TUIHelpPopup = oop_utils.new_class(TUIOverlayPopup)

---@class TUIHelpPopup.constructor.opts : TUIOverlayPopup.constructor.opts
---@field private toggle_keymap any

---@param opts TUIHelpPopup.constructor.opts
---@return TUIHelpPopup
function TUIHelpPopup.new(opts)
  opts = opts_utils.deep_extend({}, opts)

  local obj = TUIOverlayPopup.new(opts)
  setmetatable(obj, TUIHelpPopup)
  ---@cast obj TUIHelpPopup

  local title = obj.top_border_text:prepend("left")
  title:render("Help")

  return obj
end

---@param mode string
---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function TUIPopup:_map(mode, key, name, handler, opts)
  opts = opts_utils.extend({ force = false }, opts)
  name = name or "?"

  if self._tui_keymaps[key] and not opts.force then
    error(
      ("Key %s is already mapped to %s"):format(key, self._tui_keymaps[key])
    )
    return
  end
  NuiPopup.map(self, mode, key, handler)
  self._tui_keymaps[key] = name
end

---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function TUIPopup:map(key, name, handler, opts) error("Not implemented") end

---@param mode string
---@param popup TUISidePopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function TUIPopup:_map_remote(mode, popup, key, name, opts)
  self:_map(mode, key, name, function()
    -- Looks like window doesn't get redrawn if we don't switch to it
    -- vim.api.nvim_win_call(popup.winid, function() vim.api.nvim_input(key) end)

    vim.api.nvim_set_current_win(popup.winid)
    vim.api.nvim_input(key)
    -- Because nvim_input is non-blocking, so we need to schedule the switch such that the switch happens after the input
    vim.schedule(function() vim.api.nvim_set_current_win(self.winid) end)
  end, opts)
end

---@param popup TUISidePopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function TUIPopup:map_remote(popup, name, key, opts) error("Not implemented") end

---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function TUIMainPopup:map(key, name, handler, opts)
  self:_map("t", key, name, handler, opts)
end

---@param popup TUISidePopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function TUIMainPopup:map_remote(popup, key, name, opts)
  self:_map_remote("t", popup, key, name, opts)
end

---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function TUISidePopup:map(key, name, handler, opts)
  self:_map("n", key, name, handler, opts)
end

---@param popup TUISidePopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function TUISidePopup:map_remote(popup, key, name, opts)
  self:_map_remote("n", popup, key, name, opts)
end

return {
  AbstractPopup = TUIPopup,
  MainPopup = TUIMainPopup,
  SidePopup = TUISidePopup,
  OverlayPopup = TUIOverlayPopup,
  HelpPopup = TUIHelpPopup,
}
