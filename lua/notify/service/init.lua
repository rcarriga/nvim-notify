local util = require("notify.util")
local NotificationBuf = require("notify.service.buffer")

---@class NotificationService
---@field private _running boolean
---@field private _pending FIFOQueue
---@field private _receiver fun(pending: FIFOQueue, time: number): boolean
local NotificationService = {}

function NotificationService:new(receiver)
  local service = {
    _receiver = receiver,
    _pending = util.FIFOQueue(),
    _running = false,
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

function NotificationService:push(notif)
  local buf = vim.api.nvim_create_buf(false, true)
  local notif_buf = NotificationBuf(buf, notif)
  notif_buf:render()
  self._pending:push(notif_buf)
  if not self._running then
    self:_run()
  end
end

function NotificationService:dismiss()
  local bufs = vim.api.nvim_list_bufs()
  local notif_wins = {}
  for _, buf in pairs(bufs) do
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 and vim.api.nvim_buf_get_option(buf, "filetype") == "notify" then
      notif_wins[#notif_wins + 1] = win
    end
  end
  for _, win in pairs(notif_wins) do
    pcall(vim.api.nvim_win_close, win, true)
  end
end

---@param receiver fun(pending: FIFOQueue, time: number): boolean
---@return NotificationService
return function(receiver)
  return NotificationService:new(receiver)
end
