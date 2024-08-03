local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local oop_utils = require("utils.oop")

-- Map of active controllers
--
---@class TUIControllerMap
---@field _id_map table<TUIControllerId, TUIController>
---@field most_recent? TUIController
local TUIControllerMap = oop_utils.new_class()

function TUIControllerMap.new()
  return setmetatable({
    _id_map = {},
    most_recent = nil,
  }, TUIControllerMap)
end

-- Retrieve a controller by its ID
--
---@param id TUIControllerId
---@return TUIController | nil
function TUIControllerMap:get(id) return self._id_map[id] end

-- Remove a controller by its ID
--
---@param id TUIControllerId
function TUIControllerMap:remove(id)
  local controller = self:get(id)
  self._id_map[id] = nil

  if self.most_recent == controller then self.most_recent = nil end
end

-- Add a controller to the index
--
---@param controller TUIController
function TUIControllerMap:add(controller)
  self._id_map[controller._id] = controller
end

-- Retrieve all controllers
--
---@return TUIController[]
function TUIControllerMap:all() return tbl_utils.values(self._id_map) end

return TUIControllerMap
