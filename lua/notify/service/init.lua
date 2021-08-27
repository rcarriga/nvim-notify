local util = require("notify.util")
local NotificationBuf = require("notify.service.buffer")
local Notification = require("notify.service.notification")

---@class NotificationService
---@field private _running boolean
---@field private _pending FIFOQueue
---@field private _receiver fun(pending: FIFOQueue, time: number): boolean
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
  local succees, updated = pcall(self._receiver, self._pending, 30 / 1000)
  if not succees then
    print("Error running notification service: " .. updated)
    self._running = false
    return
  end
  if not updated then
    self._running = false
    return
  end
  vim.defer_fn(function()
    self:_run()
  end, 30)
end

---@param message string | string[]
---@param level string | number
---@param opts NotifyOptions
function NotificationService:push(message, level, opts)
  local notif = Notification(message, level, opts or {})
  local buf = vim.api.nvim_create_buf(false, true)
  local notif_buf = NotificationBuf(buf, notif)
  notif_buf:render()
  self._pending:push(notif_buf)
  if not self._running then
    self:_run()
  end
end

---@param receiver fun(pending: FIFOQueue, time: number): boolean
---@return NotificationService
return function(receiver)
  return NotificationService:new(receiver)
end
