local tbl_utils = require("utils.table")

local NuiLine = require("nui.line")
local NuiText = require("nui.text")

---@enum TUIPopupBorderText.section
local Section = {
  left = "left",
  right = "right",
}

---@alias TUIPopupBorderText.component.subscriber fun(output: NuiText | string)

---@class TUIPopupBorderText.component
---@field _subscribers TUIPopupBorderText.component.subscriber[]
---@field output NuiText | string
local PopupBorderTextComponent = {}
PopupBorderTextComponent.__index = PopupBorderTextComponent
PopupBorderTextComponent.__is_class = true

---@return TUIPopupBorderText.component
function PopupBorderTextComponent.new()
  local obj = {
    _subscribers = {},
    output = "",
  }
  setmetatable(obj, PopupBorderTextComponent)
  ---@cast obj TUIPopupBorderText.component

  return obj
end

---@param output NuiText | string
function PopupBorderTextComponent:render(output)
  self.output = output

  for _, subscriber in ipairs(self._subscribers) do
    subscriber(output)
  end
end

---@param callback TUIPopupBorderText.component.subscriber
function PopupBorderTextComponent:on_render(callback)
  callback(self.output)
  table.insert(self._subscribers, callback)
end

---@class TUIPopupBorderText
---@field _config TUIConfig
---@field _components table<TUIPopupBorderText.section, TUIPopupBorderText.component[]>
---@field _subscribers (fun(output: NuiLine)[])
---@field _output NuiLine | string
---@field _popup TUIPopup For retrieving the popup's width
---@field _fake_border NuiText
local PopupBorderText = {}
PopupBorderText.__index = PopupBorderText
PopupBorderText.__is_class = true

---@param opts { config: TUIConfig, popup: TUIPopup }
---@return TUIPopupBorderText
function PopupBorderText.new(opts)
  local obj = {
    _config = opts.config,
    _popup = opts.popup,
    _components = {
      [Section.left] = {},
      [Section.right] = {},
    },
    _output = "",
    _subscribers = {},
    _fake_border = NuiText(""),
  }
  setmetatable(obj, PopupBorderText)
  ---@cast obj TUIPopupBorderText

  return obj
end

---@param section TUIPopupBorderText.section
---@return TUIPopupBorderText.component
function PopupBorderText:prepend(section)
  local component = PopupBorderTextComponent.new()
  table.insert(self._components[section], 1, component)

  component:on_render(function(output)
    self:_render()
  end)

  return component
end

---@param section TUIPopupBorderText.section
---@return TUIPopupBorderText.component
function PopupBorderText:append(section)
  local component = PopupBorderTextComponent.new()
  table.insert(self._components[section], component)

  component:on_render(function(output)
    self:_render()
  end)

  return component
end

function PopupBorderText:_render()
  if not self._popup.winid then
    return
  end

  local output = NuiLine()

  local left_texts = tbl_utils.map(self._components[Section.left], function(_, c)
    return c.output
  end)
  local right_texts = tbl_utils.map(self._components[Section.right], function(_, c)
    return c.output
  end)

  -- TODO: make these char configurable
  local padding = " "
  local sep = " "

  local left_width = tbl_utils.sum(left_texts, function(_, t)
    if type(t) == "string" then
      return #t
    else
      return t:length()
    end
  end)
  local total_left_width
  if left_width == 0 then
    total_left_width = 0
  else
    total_left_width = left_width + (#left_texts - 1) * #sep + #padding * 2
  end
  local right_width = tbl_utils.sum(right_texts, function(_, t)
    if type(t) == "string" then
      return #t
    else
      return t:length()
    end
  end)
  local total_right_width
  if right_width == 0 then
    total_right_width = 0
  else
    total_right_width = right_width + (#right_texts - 1) * #sep + #padding * 2
  end

  local remaining_width = vim.api.nvim_win_get_width(self._popup.winid) - total_left_width - total_right_width

  if left_width > 0 then
    output:append(padding)
    for i, text in ipairs(left_texts) do
      if i < #left_texts then
        output:append(sep)
      end
      output:append(text)
    end
    output:append(padding)
  end

  -- TODO: rely on nui native API instead (once this feat is available)
  self._fake_border:set(("─"):rep(remaining_width), "FloatBorder")
  output:append(self._fake_border)

  if right_width > 0 then
    output:append(padding)
    for i, text in ipairs(right_texts) do
      if i < #right_texts then
        output:append(sep)
      end
      output:append(text)
    end
    output:append(padding)
  end

  self._output = output
  for _, subscriber in ipairs(self._subscribers) do
    subscriber(output)
  end
end

function PopupBorderText:clear()
  self._components = {
    [Section.left] = {},
    [Section.right] = {},
  }
end

---@param callback fun(output: NuiLine | string)
function PopupBorderText:on_render(callback)
  callback(self._output)
  table.insert(self._subscribers, callback)
end

return PopupBorderText