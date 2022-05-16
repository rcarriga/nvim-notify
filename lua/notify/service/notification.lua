---@class Notification
---@field id integer
---@field level string
---@field message string[]
---@field timeout number | nil
---@field title string[]
---@field icon string
---@field time number
---@field width number
---@field hide_from_history boolean
---@field keep fun(): boolean
---@field on_open fun(win: number) | nil
---@field on_close fun(win: number) | nil
---@field render fun(buf: integer, notification: Notification, highlights: table<string, string>)
local Notification = {}

function Notification:new(id, message, level, opts, config)
  if type(level) == "number" then
    level = vim.lsp.log_levels[level]
  end
  if type(message) == "string" then
    message = vim.split(message, "\n")
  end
  level = vim.fn.toupper(level or "info")
  local time = vim.fn.localtime()
  local title = opts.title or ""
  if type(title) == "string" then
    title = { title, vim.fn.strftime("%H:%M", time) }
  end
  local notif = {
    id = id,
    message = message,
    title = title,
    icon = opts.icon or config.icons()[level] or config.icons().INFO,
    time = time,
    timeout = opts.timeout,
    level = level,
    keep = opts.keep,
    on_open = opts.on_open,
    on_close = opts.on_close,
    render = opts.render,
    hide_from_history = opts.hide_from_history,
  }
  self.__index = self
  setmetatable(notif, self)
  return notif
end

function Notification:record()
  return {
    message = self.message,
    level = self.level,
    time = self.time,
    title = self.title,
    icon = self.icon,
    render = self.render,
  }
end

---@param message string | string[]
---@param level string | number
---@param opts notify.Options
return function(id, message, level, opts, config)
  return Notification:new(id, message, level, opts, config)
end
