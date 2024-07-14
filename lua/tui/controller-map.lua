local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")

-- Map of active controllers
--
---@class TUIControllerMap
---@field _id_map table<TUIControllerId, TUIController>
---@field most_recent? TUIController
local ControllerMap = {}
ControllerMap.__index = ControllerMap
ControllerMap.__is_class = true

function ControllerMap.new()
  return setmetatable({
    _id_map = {},
    most_recent = nil,
  }, ControllerMap)
end

-- Retrieve a controller by its ID
--
---@param id TUIControllerId
---@return TUIController | nil
function ControllerMap:get(id) return self._id_map[id] end

-- Remove a controller by its ID
--
---@param id TUIControllerId
function ControllerMap:remove(id)
  local controller = self:get(id)
  self._id_map[id] = nil

  if self.most_recent == controller then self.most_recent = nil end
end

-- Add a controller to the index
--
---@param controller TUIController
function ControllerMap:add(controller) self._id_map[controller._id] = controller end

-- Retrieve all controllers
--
---@return TUIController[]
function ControllerMap:all() return tbl_utils.values(self._id_map) end

return ControllerMap
