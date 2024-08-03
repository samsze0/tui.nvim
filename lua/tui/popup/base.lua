local NuiPopup = require("nui.popup")
local NuiEvent = require("nui.utils.autocmd").event
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local file_utils = require("utils.files")
local PopupBorderText = require("tui.popup-border-text")
local winhighlight_utils = require("utils.winhighlight")
local oop_utils = require("utils.oop")
local shared = require("tui.popup.shared")

---@class TUIPopup
---@field _name string
---@field _nui_popup NuiPopup
---@field _config TUIConfig
---@field _keymaps table<string, string> Mappings of key to name (of the handler)
---@field top_border_text TUIPopupBorderText
---@field bottom_border_text TUIPopupBorderText
local TUIPopup = oop_utils.new_class()

---@class TUIPopup.constructor.opts
---@field nui_popup_opts? nui_popup_options
---@field config TUIConfig

---@param opts TUIPopup.constructor.opts
---@return TUIPopup
function TUIPopup.new(opts)
  local config = opts.config.value

  ---@type nui_popup_options
  local nui_popup_opts = {
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
    zindex = shared.NORMAL_POPUP_Z_INDEX,
  }

  nui_popup_opts = opts_utils.deep_extend(nui_popup_opts, opts.nui_popup_opts)

  local win_hl = opts_utils.extend({
    Normal = "Normal",
    FloatBorder = config.highlight_groups.border.inactive,
  }, winhighlight_utils.from_str(nui_popup_opts.win_options.winhighlight))

  nui_popup_opts.win_options.winhighlight = winhighlight_utils.to_str(win_hl)

  local nui_popup = NuiPopup(nui_popup_opts)

  local obj = {
    _nui_popup = nui_popup,
    _config = config,
    _keymaps = {},
  }
  setmetatable(obj, TUIPopup)
  ---@cast obj TUIPopup

  obj.top_border_text = PopupBorderText.new({
    config = opts.config,
    popup = obj,
  })
  obj.bottom_border_text = PopupBorderText.new({
    config = opts.config,
    popup = obj,
  })

  obj.top_border_text:on_render(
    function(output) obj._nui_popup.border:set_text("top", output, "left") end
  )
  obj.bottom_border_text:on_render(
    function(output) obj._nui_popup.border:set_text("bottom", output, "left") end
  )

  local set_border_hl = function(hl_group)
    obj._nui_popup.border:set_highlight(hl_group)
  end

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

function TUIPopup:focus()
  local winid = self:get_window()
  if not winid then return end

  vim.api.nvim_set_current_win(winid)
end

-- Get current mappings of keys to handler names
--
---@return table<string, string>
function TUIPopup:keymaps() return self._keymaps end

function TUIPopup:_info(...) self._config.value.notifier.info(...) end

function TUIPopup:_warn(...) self._config.value.notifier.warn(...) end

function TUIPopup:_error(...) self._config.value.notifier.error(...) end

-- Return the lines of the buffer. If buffer is invalid, return empty list
--
---@return string[]
function TUIPopup:get_lines()
  local bufnr = self:get_buffer()
  if not bufnr then return {} end
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- Set the lines of the buffer. If buffer is invalid, do nothing
-- If `cursor_pos` option is passed but window is invalid, then ignore
--
-- This method will always reset the filetype
--
---@param lines string[]
---@param opts? { cursor_pos?: number[], filetype?: string }
function TUIPopup:set_lines(lines, opts)
  opts = opts_utils.extend({}, opts)

  local bufnr = self:get_buffer()
  if not bufnr then return end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  if opts.cursor_pos then
    local winid = self:get_window()
    if not winid then return end

    vim.api.nvim_win_set_cursor(winid, opts.cursor_pos or { 1, 0 })
    vim.api.nvim_win_call(winid, function() vim.cmd("normal! zz") end)
  end

  vim.bo[bufnr].filetype = opts.filetype or ""
end

-- Show the content of a file in the popup
--
-- If file cannot be shown for any reason, it will show an error message in the popup instead
--
---@param path string
---@param opts? { cursor_pos?: number[], exclude_filetypes?: string[] }
---@return boolean success
function TUIPopup:show_file_content(path, opts)
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

  local bufnr = self:get_buffer()
  if not bufnr then
    self:_warn("Buffer is invalid")
    return false
  end

  vim.bo[bufnr].filetype = filetype or ""

  return true
end

---@param buf number
---@param opts? { cursor_pos?: number[] }
function TUIPopup:show_buf_content(buf, opts)
  opts = opts or {}

  local path = vim.api.nvim_buf_get_name(buf)
  self:show_file_content(path, { cursor_pos = opts.cursor_pos })
end

---@param mode string
---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function TUIPopup:_map(mode, key, name, handler, opts)
  opts = opts_utils.extend({ force = false }, opts)
  name = name or "?"

  if self._keymaps[key] and not opts.force then
    error(("Key %s is already mapped to %s"):format(key, self._keymaps[key]))
    return
  end
  self._nui_popup:map(mode, key, handler)
  self._keymaps[key] = name
end

---@param mode string
---@param popup TUIUnderlayPopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function TUIPopup:_map_remote(mode, popup, key, name, opts)
  self:_map(mode, key, name, function()
    -- Looks like window doesn't get redrawn if we don't switch to it
    -- vim.api.nvim_win_call(popup.winid, function() vim.api.nvim_input(key) end)

    local remote_winid = popup:get_window()
    if not remote_winid then
      self:_warn("Window is invalid")
      return
    end

    vim.api.nvim_set_current_win(remote_winid)
    vim.api.nvim_input(key)
    -- Because nvim_input is non-blocking, so we need to schedule the switch such that the switch happens after the input
    vim.schedule(function() self:focus() end)
  end, opts)
end

---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function TUIPopup:map(key, name, handler, opts)
  self:_map("n", key, name, handler, opts)
end

---@param popup TUIUnderlayPopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function TUIPopup:map_remote(popup, key, name, opts)
  self:_map_remote("n", popup, key, name, opts)
end

-- Return the window ID of the popup. If window is invalid, return nil
--
---@return number|nil
function TUIPopup:get_window()
  local win = self._nui_popup.winid
  if win == nil or not vim.api.nvim_win_is_valid(win) then return nil end
  return win
end

-- Return the buffer number of the popup. If buffer is invalid, return nil
--
---@return number|nil
function TUIPopup:get_buffer()
  local buf = self._nui_popup.bufnr
  if buf == nil or not vim.api.nvim_buf_is_valid(buf) then return nil end
  return buf
end

---@param event string|string[]
---@param handler string|function
---@param opts? { nested?: boolean, once?: boolean }
function TUIPopup:on(event, handler, opts)
  return self._nui_popup:on(event, handler, opts)
end

---@return NuiPopup
function TUIPopup:get_nui_popup() return self._nui_popup end

function TUIPopup:show() self._nui_popup:show() end

return TUIPopup
