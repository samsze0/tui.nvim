local tbl_utils = require("utils.table")
local lang_utils = require("utils.lang")
local oop_utils = require("utils.oop")

---@alias TUIEventMapAction string

---@class TUIEventMap
---@field private value table<string, TUIEventMapAction[]>
local TUIEventMap = oop_utils.create_class()

---@param base? TUIEventMap
---@return TUIEventMap self
function TUIEventMap.new(base)
  local obj = base or {}
  setmetatable(obj, TUIEventMap)
  obj.value = {}
  return obj
end

-- Add binds to the map
--
---@param binds table<string, TUIEventMapAction | TUIEventMapAction[]>
---@return TUIEventMap self
function TUIEventMap:extend(binds)
  for k, v in pairs(binds) do
    if type(v) == "table" then
      TUIEventMap:append(k, unpack(v))
    else
      TUIEventMap:append(k, v)
    end
  end

  return self
end

-- Add bind(s) to the map
--
---@param event string
---@param binds TUIEventMapAction[]
---@param opts { prepend: boolean }
---@return TUIEventMap self
function TUIEventMap:_add(event, binds, opts)
  lang_utils.switch(type(self.value[event]), {
    ["nil"] = function() self.value[event] = binds end,
    ["table"] = function()
      if opts.prepend then
        self.value[event] = tbl_utils.list_extend(binds, self.value[event])
      else
        self.value[event] = tbl_utils.list_extend(self.value[event], binds)
      end
    end,
  }, function() error("Invalid value") end)
  return self
end

-- Append bind(s) to the map
--
---@param event string
---@vararg TUIEventMapAction
---@return TUIEventMap self
function TUIEventMap:append(event, ...)
  local binds = { ... }
  return self:_add(event, binds, { prepend = false })
end

-- Prepend bind(s) to the map
--
---@param event string
---@vararg TUIEventMapAction
---@return TUIEventMap self
function TUIEventMap:prepend(event, ...)
  local binds = { ... }
  return self:_add(event, binds, { prepend = true })
end

-- Get bind(s) from the map by event name
--
---@param event string
---@return TUIEventMapAction[]
function TUIEventMap:get(event)
  local actions = self.value[event]
  if not actions then return {} end
  return actions
end

-- TODO: this should only be for fzf
function TUIEventMap:__tostring()
  return table.concat(
    tbl_utils.map(
      self.value,
      function(ev, actions)
        return ("%s:%s"):format(ev, table.concat(actions, "+"))
      end
    ),
    ","
  )
end

return TUIEventMap
