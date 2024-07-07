local NuiPopup = require("nui.popup")
local NuiEvent = require("nui.utils.autocmd").event
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")

---@type nui_popup_options
local popup_opts = {
  focusable = true,
  border = {
    style = "rounded",
  },
  win_options = {
    winblend = 0,
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
  },
}

---@class TUIPopup: NuiPopup
---@field _tui_keymaps table<string, string> Mappings of key to name (of the handler)
local Popup = {}
Popup.__index = Popup
Popup.__is_class = true
setmetatable(Popup, { __index = NuiPopup })

---@param opts? nui_popup_options
---@return TUIPopup
function Popup.new(opts)
  opts = opts_utils.deep_extend(popup_opts, opts)

  local obj = NuiPopup(opts)
  setmetatable(obj, Popup)
  ---@cast obj TUIPopup

  obj._tui_keymaps = {}

  return obj
end

function Popup:focus() vim.api.nvim_set_current_win(self.winid) end

-- Get current mappings of keys to handler names
--
---@return table<string, string>
function Popup:keymaps() return self._tui_keymaps end

---@class TUIMainPopup: TUIPopup
local MainPopup = {}
MainPopup.__index = MainPopup
MainPopup.__is_class = true
setmetatable(MainPopup, { __index = Popup })

---@param config? nui_popup_options
---@return TUIMainPopup
function MainPopup.new(config)
  config = opts_utils.deep_extend({
    enter = false, -- This can mute BufEnter event
    buf_options = {
      modifiable = false,
      filetype = "tui",
    },
    win_options = {},
  }, config)

  local obj = Popup.new(config)
  setmetatable(obj, MainPopup)
  ---@cast obj TUIMainPopup

  obj:on(NuiEvent.BufEnter, function() vim.cmd("startinsert!") end)

  return obj
end

-- TODO: move map and map_remote to Popup

---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function MainPopup:map(key, name, handler, opts)
  opts = opts_utils.extend({ force = false }, opts)
  name = name or "?"

  if self._tui_keymaps[key] and not opts.force then
    error(
      ("Key %s is already mapped to %s"):format(key, self._tui_keymaps[key])
    )
    return
  end
  NuiPopup.map(self, "t", key, handler)
  self._tui_keymaps[key] = name
end

---@param popup TUISidePopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function MainPopup:map_remote(popup, name, key, opts)
  self:map(key, name, function()
    -- Looks like window doesn't get redrawn if we don't switch to it
    -- vim.api.nvim_win_call(popup.winid, function() vim.api.nvim_input(key) end)

    vim.api.nvim_set_current_win(popup.winid)
    vim.api.nvim_input(key)
    -- Because nvim_input is non-blocking, so we need to schedule the switch such that the switch happens after the input
    vim.schedule(function() vim.api.nvim_set_current_win(self.winid) end)
  end, opts)
end

---@class TUISidePopup: TUIPopup
local SidePopup = {}
SidePopup.__index = SidePopup
SidePopup.__is_class = true
setmetatable(SidePopup, { __index = Popup })

---@param opts? nui_popup_options
---@return TUISidePopup
function SidePopup.new(opts)
  opts = opts_utils.deep_extend({
    buf_options = {
      modifiable = true,
    },
    win_options = {
      number = false,
      wrap = false,
    },
  }, opts)

  local obj = Popup.new(opts)
  setmetatable(obj, SidePopup)
  ---@cast obj TUISidePopup

  return obj
end

---@return string[]
function SidePopup:get_lines()
  return vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
end

---@param lines string[]
---@param opts? { cursor_pos?: number[] }
function SidePopup:set_lines(lines, opts)
  opts = opts_utils.extend({}, opts)

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  if opts.cursor_pos then
    vim.api.nvim_win_set_cursor(self.winid, opts.cursor_pos or { 1, 0 })
    vim.api.nvim_win_call(self.winid, function() vim.cmd("normal! zz") end)
  end
end

---@param path string
---@param opts? { cursor_pos?: number[] }
function SidePopup:show_file_content(path, opts)
  opts = opts_utils.extend({}, opts)

  if vim.fn.filereadable(path) ~= 1 then
    self:set_lines({ "File not readable, or doesnt exist" })
    return
  end

  local file_mime, status, _ = terminal_utils.system("file --mime " .. path)
  if status ~= 0 then
    self:set_lines({ "Cannot determine if file is binary" })
    return
  end
  ---@cast file_mime string

  local is_binary = file_mime:match("charset=binary")

  if is_binary then
    self:set_lines({ "No preview available for binary file" })
    return
  end

  local lines = vim.fn.readfile(path)
  local filename = vim.fn.fnamemodify(path, ":t")
  local filetype = vim.filetype.match({
    filename = filename,
    contents = lines,
  })
  self:set_lines(lines, { cursor_pos = opts.cursor_pos })
  vim.bo[self.bufnr].filetype = filetype or ""
end

---@param buf number
---@param opts? { cursor_pos?: number[] }
function SidePopup:show_buf_content(buf, opts)
  opts = opts or {}

  local path = vim.api.nvim_buf_get_name(buf)
  self:show_file_content(path, { cursor_pos = opts.cursor_pos })
end

---@class TUIHelpPopup: TUIPopup
local HelpPopup = {}
HelpPopup.__index = HelpPopup
HelpPopup.__is_class = true
setmetatable(HelpPopup, { __index = Popup })

---@type nui_popup_options
local help_popup_opts = {
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
}

---@param opts? nui_popup_options
---@return TUIHelpPopup
function HelpPopup.new(opts)
  opts = opts_utils.deep_extend(help_popup_opts, opts)

  local obj = Popup.new(opts)
  setmetatable(obj, HelpPopup)
  ---@cast obj TUIHelpPopup

  -- FIX: border text not showing
  obj.border:set_text("top", " Help ", "left")

  return obj
end

---@param lines string[]
function HelpPopup:set_lines(lines)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
end

---@param keymaps table<string, string>
function HelpPopup:set_keymaps(keymaps)
  local items = tbl_utils.map(
    keymaps,
    function(key, name) return name .. " : " .. key end
  )
  items = tbl_utils.sort(items, function(a, b) return a < b end)
  self:set_lines(items)
end

return {
  AbstractPopup = Popup,
  MainPopup = MainPopup,
  SidePopup = SidePopup,
  HelpPopup = HelpPopup,
}
