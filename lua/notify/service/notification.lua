local config = require("notify.config")

---@class Notification
---@field level string
---@field message string
---@field timeout number | nil
---@field title string
---@field icon string
---@field time number
---@field width number
---@field keep fun(): boolean
---@field on_open fun(win: number) | nil
---@field on_close fun(win: number) | nil
local Notification = {}

function Notification:new(message, level, opts)
  if type(level) == "number" then
    level = vim.lsp.log_levels[level]
  end
  if type(message) == "string" then
    message = vim.split(message, "\n")
  end
  level = vim.fn.toupper(level or "info")
  local notif = {
    message = message,
    title = opts.title or "",
    icon = opts.icon or config.icons()[level] or config.icons().INFO,
    time = vim.fn.localtime(),
    timeout = opts.timeout,
    level = level,
    keep = opts.keep,
    on_open = opts.on_open,
    on_close = opts.on_close,
  }
  self.__index = self
  setmetatable(notif, self)
  return notif
end

---@class NotifyOptions
---@field title string | nil
---@field icon string | nil
---@field timeout number | nil
---@field on_open fun(win: number) | nil
---@field on_close fun(win: number) | nil
---@field keep fun(win: number): boolean | nil

---@param message string | string[]
---@param level string | number
---@param opts NotifyOptions
return function(message, level, opts)
  return Notification:new(message, level, opts)
end
