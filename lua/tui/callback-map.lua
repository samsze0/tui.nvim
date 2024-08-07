local uuid_utils = require("utils.uuid")

---@alias TUICallback function

---@class TUICallbackMap
---@field private value table<string, TUICallback> Callback map
local TUICallbackMap = {}
TUICallbackMap.__index = TUICallbackMap

---@param base? TUICallbackMap
---@return TUICallbackMap self
function TUICallbackMap.new(base)
  local obj = base or {}
  setmetatable(obj, TUICallbackMap)
  obj.value = {}
  return obj
end

-- Add callback to the map
--
---@param callback TUICallback
---@return string key
function TUICallbackMap:add(callback)
  local key = self:empty_slot()
  self.value[key] = callback
  return key
end

-- Remove callback from the map
--
---@param key string
function TUICallbackMap:remove(key)
  if not self:exists(key) then error("Callback not found: " .. key) end
  self.value[key] = nil
end

-- Add callback and return a function to remove the callback from the map
--
---@param callback TUICallback
---@return fun(): nil
function TUICallbackMap:add_and_return_remove_fn(callback)
  local key = self:add(callback)
  return function() self:remove(key) end
end

-- Get callback from the map
--
---@param key string
---@return TUICallback
function TUICallbackMap:get(key)
  if not self:exists(key) then error("Callback not found: " .. key) end
  return self.value[key]
end

-- Find empty slot in the map and return the key
--
---@return string key
function TUICallbackMap:empty_slot()
  local key = uuid_utils.v4()
  local retry_count = 3
  while self:exists(key) and retry_count >= 1 do
    retry_count = retry_count - 1
    key = uuid_utils.v4()
  end
  if self:exists(key) then error("Failed to find empty slot") end
  return key
end

function TUICallbackMap:exists(key) return self.value[key] ~= nil end

-- Invoke callback
--
---@param key string
---@vararg any
function TUICallbackMap:invoke(key, ...)
  local cb = self:get(key)
  local args = { ... }
  vim.schedule(function() cb(unpack(args)) end)
end

-- Invoke callback if key exists, otherwise do nothing
--
---@param key string
---@vararg any
function TUICallbackMap:invoke_if_exists(key, ...)
  if not self:exists(key) then return end
  local args = { ... }
  self:invoke(key, unpack(args))
end

-- Invoke all callbacks
--
---@vararg any
function TUICallbackMap:invoke_all(...)
  local args = { ... }
  for _, cb in pairs(self.value) do
    vim.schedule(function() cb(unpack(args)) end)
  end
end

return TUICallbackMap
