local util = require("notify.util")

local config = util.lazy_require("notify.config")
local stages = util.lazy_require("notify.stages")
---@type fun(message: string | string[], level: string | number, opts: NotifyOptions): Notification
local Notification = util.lazy_require("notify.service.notification")
---@type fun(stages: function[]): WindowAnimator
local WindowAnimator = util.lazy_require("notify.windows")
---@type fun(receiver: fun(pending: FIFOQueue, time: number): table | nil): NotificationService
local NotificationService = util.lazy_require("notify.service")

local service
---@type Notification[]
local notifications = {}

local M = {}

function M.setup(user_config)
  config.setup(user_config)
  local animator_stages = config.stages()
  animator_stages = type(animator_stages) == "string" and stages[animator_stages] or animator_stages
  local animator = WindowAnimator(animator_stages)
  service = NotificationService(function(...)
    return animator:render(...)
  end)
end

---@param message string | string[]
---@param level string | number
---@param opts NotifyOptions
local function notify(message, level, opts)
  if not service then
    M.setup()
  end
  local notification = Notification(message, level, opts or {})
  table.insert(notifications, notification)
  service:push(notification)
end

function M.history()
  return vim.tbl_map(function(notif)
    return { message = notif.message, level = notif.level, time = notif.time }
  end, notifications)
end

setmetatable(M, {
  __call = function(_, m, l, o)
    if vim.in_fast_event() then
      vim.schedule(function()
        notify(m, l, o)
      end)
    else
      notify(m, l, o)
    end
  end,
})

return M
