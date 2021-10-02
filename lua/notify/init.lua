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

  vim.cmd([[command! Notifications :lua require("notify")._print_history()<CR>]])
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
    return {
      message = notif.message,
      level = notif.level,
      time = notif.time,
      title = notif.title,
      icon = notif.icon,
    }
  end, notifications)
end

function M._print_history()
  for _, notif in ipairs(M.history()) do
    vim.api.nvim_echo({
      { vim.fn.strftime("%FT%T", notif.time), "NotifyLogTime" },
      { " ", "MsgArea" },
      { notif.title[1], "NotifyLogTitle" },
      { #notif.title[1] > 0 and " " or "", "MsgArea" },
      { notif.icon, "Notify" .. notif.level .. "Title" },
      { #notif.title[1] > 0 and " " or "", "MsgArea" },
      { notif.level, "Notify" .. notif.level .. "Title" },
      { " ", "MsgArea" },
      { table.concat(notif.message, "\n"), "MsgArea" },
    }, false, {})
  end
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
