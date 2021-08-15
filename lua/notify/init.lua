local NotificationRenderer = require("notify.render")
local config = require("notify.config")
local util = require("notify.util")

local renderer = NotificationRenderer()

local running = false

local function run()
  running = true
  local success, ran = pcall(renderer.step, renderer, 30 / 1000)
  if not success then
    print("Error running notification service: " .. ran)
    running = false
    return
  end
  if not ran then
    running = false
    return
  end
  vim.defer_fn(run, 30)
end

local notifications = {}

---@class Notification
---@field level number
---@field level_name string
---@field message string
---@field timeout number
---@field title string
---@field icon string
---@field time number
---@field width number
---@field on_open fun(win: number) | nil
---@field on_close fun(win: number) | nil
local Notification = {}

function Notification:new(message, level, opts)
  if type(message) == "string" then
    message = vim.split(message, "\n")
  end
  -- Convert level names to number (or default)
  level = util.to_level(level)
  local notif = {
    message = message,
    title = opts.title or "",
    icon = opts.icon or config.levels()[level].icon or 
        config.levels()[config.default_level()].icon,
    time = vim.fn.localtime(),
    timeout = opts.timeout or 5000,
    level = level,
    level_name = string.upper(config.levels()[level].name),
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

---@param opts NotifyOptions
local function notify(_, message, level, opts)
  vim.schedule(function()
    local notif = Notification:new(message, level, opts or {})
    notifications[#notifications + 1] = notif
    renderer:queue(notif)
    if not running then
      run()
    end
  end)
end

local M = {}

setmetatable(M, { __call = notify })

return M
