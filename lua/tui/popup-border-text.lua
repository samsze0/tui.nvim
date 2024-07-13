local NuiLine = require("nui.line")

---@enum TUIPopupBorderText.section
local Section = {
  left = "left",
  right = "right",
}

---@alias TUIPopupBorderText.component.render fun(output: NuiText | string)
---@alias TUIPopupBorderText.component.renderer fun(render: TUIPopupBorderText.component.render)
---@alias TUIPopupBorderText.component.subscriber fun(output: NuiText | string)

---@class TUIPopupBorderText.component
---@field _subscribers TUIPopupBorderText.component.subscriber[]
---@field output NuiText | string
---@field render TUIPopupBorderText.component.render
local PopupBorderTextComponent = {}
PopupBorderTextComponent.__index = PopupBorderTextComponent
PopupBorderTextComponent.__is_class = true

---@param renderer TUIPopupBorderText.component.renderer
---@return TUIPopupBorderText.component
function PopupBorderTextComponent.new(renderer)
  local obj = {
    _subscribers = {},
    output = "",
  }
  setmetatable(obj, PopupBorderTextComponent)
  ---@cast obj TUIPopupBorderText.component

  obj.render = function(output)
    obj.output = output

    for _, subscriber in ipairs(obj._subscribers) do
      subscriber(output)
    end
  end

  renderer(obj.render)

  return obj
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
local PopupBorderText = {}
PopupBorderText.__index = PopupBorderText
PopupBorderText.__is_class = true

---@param opts { config: TUIConfig }
---@return TUIPopupBorderText
function PopupBorderText.new(opts)
  local obj = {
    _config = opts.config,
    _components = {
      [Section.left] = {},
      [Section.right] = {},
    },
    _output = "",
    _subscribers = {},
  }
  setmetatable(obj, PopupBorderText)
  ---@cast obj TUIPopupBorderText

  return obj
end

---@param section TUIPopupBorderText.section
---@param component_renderer TUIPopupBorderText.component.renderer
function PopupBorderText:prepend(section, component_renderer)
  local component = PopupBorderTextComponent.new(component_renderer)
  table.insert(self._components[section], 1, component)

  component:on_render(function(output)
    self:_render()
  end)
end

---@param section TUIPopupBorderText.section
---@param component_renderer TUIPopupBorderText.component.renderer
function PopupBorderText:append(section, component_renderer)
  local component = PopupBorderTextComponent.new(component_renderer)
  table.insert(self._components[section], component)

  component:on_render(function(output)
    self:_render()
  end)
end

function PopupBorderText:_render()
  local output = NuiLine()
  for section, _ in pairs(self._components) do
    for _, component in ipairs(self._components[section]) do
      output:append(component.output)
    end
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