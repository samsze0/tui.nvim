local opts_utils = require("utils.opts")

---@class TUINotifierConfig
---@field info fun(message: string)?
---@field warn fun(message: string)?
---@field error fun(message: string)?

---@class TUIKeymapsConfig.move_to_pane
---@field left string?
---@field down string?
---@field up string?
---@field right string?

---@class TUIKeymapsConfig
---@field move_to_pane TUIKeymapsConfig.move_to_pane?
---@field maximise string?
---@field copy_filepath_to_clipboard string?

---@class TUIHighlightGroupsConfig.border
---@field active string?
---@field inactive string?

---@class TUIHighlightGroupsConfig
---@field border TUIHighlightGroupsConfig.border?

---@class TUIConfig.config
---@field keymaps TUIKeymapsConfig?
---@field default_extra_args ShellOpts?
---@field default_extra_env_vars ShellOpts?
---@field notifier TUINotifierConfig?
---@field highlight_groups TUIHighlightGroupsConfig?

-- A singleton class to store the configuration
--
---@class TUIConfig
---@field value TUIConfig.config
local Config = {}
Config.__index = Config
Config.__is_class = true

---@param config? TUIConfig.config
function Config:setup(config)
  self.value = opts_utils.deep_extend(self.value, config)
end

---@type TUIConfig.config
local default_config = {
  notifier = {
    info = function(message) vim.notify(message, vim.log.levels.INFO) end,
    warn = function(message) vim.notify(message, vim.log.levels.WARN) end,
    error = function(message) vim.notify(message, vim.log.levels.ERROR) end,
  },
  keymaps = {
    move_to_pane = {
      left = "<C-s>",
      down = "<C-d>",
      up = "<C-e>",
      right = "<C-f>",
    },
    copy_filepath_to_clipboard = "<C-y>",
    toggle_maximise = "<C-z>",
  },
  default_extra_args = {},
  default_extra_env_vars = {},
  highlight_groups = {
    border = {
      active = "TUIBorderActive",
      inactive = "TUIBorderInactive",
    },
  },
}

---@return TUIConfig
function Config.new()
  return setmetatable({
    value = opts_utils.deep_extend({}, default_config),
  }, Config)
end

return Config
