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
---@field copy_filepath_to_clipboard string?

---@alias TUIConfig.config { keymaps: TUIKeymapsConfig, default_extra_args: ShellOpts, default_extra_env_vars: ShellOpts, notifier: TUINotifierConfig }

-- A singleton class to store the configuration
--
---@class TUIConfig
---@field value TUIConfig.config
local Config = {}
Config.__index = Config
Config.__is_class = true

---@param config? { keymaps?: TUIKeymapsConfig, default_extra_args?: ShellOpts, default_extra_env_vars?: ShellOpts, notifier?: TUINotifierConfig }
function Config:setup(config)
  self.value = opts_utils.deep_extend(Config.value, config)
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
  },
  default_extra_args = {},
  default_extra_env_vars = {},
}

function Config:new()
  return setmetatable({
    value = opts_utils.deep_extend({}, default_config),
  }, Config)
end

return Config
