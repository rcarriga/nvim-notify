local util = require("notify.util")
---@type fun(buf: number, notification: Notification): NotificationBuf
local NotificationBuf = util.lazy_require("notify.service.buffer")
---@type fun(message: string | string[], level: number | string, opts: NotifyOptions): Notification
local Notification = util.lazy_require("notify.service.notification")

---@class NotificationService
---@field private _running boolean
---@field private _pending FIFOQueue
---@field private _receiver fun(pending: FIFOQueue, time: number): table | nil
---@field private _notifications Notification[]
local NotificationService = {}

function NotificationService:new(receiver)
  local service = {
    _receiver = receiver,
    _pending = util.FIFOQueue(),
    _running = false,
    _notifications = {},
  }
  self.__index = self
  setmetatable(service, self)
  return service
end

function NotificationService:_run()
  self._running = true
  local succees, updates = pcall(self._receiver, self._pending, 30 / 1000)
  if not succees then
    print("Error running notification service: " .. updates)
    self._running = false
    return
  end
  if not updates then
    self._running = false
    return
  end
  util.update_configs(updates)
  vim.defer_fn(function()
    self:_run()
  end, 30)
end

---@param message string | string[]
---@param level string | number
---@param opts NotifyOptions
function NotificationService:push(message, level, opts)
  local notif = Notification(message, level, opts or {})
  self._notifications[#self._notifications + 1] = notif
  local buf = vim.api.nvim_create_buf(false, true)
  local notif_buf = NotificationBuf(buf, notif)
  notif_buf:render()
  self._pending:push(notif_buf)
  if not self._running then
    self:_run()
  end
end

---@param receiver fun(pending: FIFOQueue, time: number): table | nil
---@return NotificationService
return function(receiver)
  return NotificationService:new(receiver)
end
