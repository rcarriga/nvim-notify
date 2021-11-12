local api = vim.api
local config = require("notify.config")

local NotifyBufHighlights = require("notify.service.buffer.highlights")

---@class NotificationBuf
---@field highlights NotifyBufHighlights
---@field _notif Notification
---@field _state "open" | "closed"
---@field _buffer number
---@field _height number
---@field _width number
---@field _max_width number | nil
local NotificationBuf = {}

local BufState = {
  OPEN = "open",
  CLOSED = "close",
}

function NotificationBuf:new(kwargs)
  local notif_buf = {
    _max_width = kwargs.max_width,
    _notif = kwargs.notif,
    _buffer = kwargs.buffer,
    _state = BufState.CLOSED,
    _width = 0,
    _height = 0,
    highlights = NotifyBufHighlights(kwargs.notif.level, kwargs.buffer),
  }
  setmetatable(notif_buf, self)
  self.__index = self
  return notif_buf
end

function NotificationBuf:open(win)
  if self._state ~= BufState.CLOSED then
    return
  end
  self._state = BufState.OPEN
  vim.schedule(function()
    if self._notif.on_open then
      self._notif.on_open(win)
    end
    if config.on_open() then
      config.on_open()(win)
    end
  end)
end

function NotificationBuf:close(win)
  if self._state ~= BufState.OPEN then
    return
  end
  self._state = BufState.CLOSED
  if self._notif.on_close then
    vim.schedule(function()
      self._notif.on_close(win)
    end)
  end
end

function NotificationBuf:height()
  return self._height
end

function NotificationBuf:width()
  return self._width
end

function NotificationBuf:should_stay()
  if self._notif.keep then
    return self._notif.keep()
  end
  return false
end

function NotificationBuf:render()
  local notif = self._notif
  local buf = self._buffer

  api.nvim_buf_set_option(buf, "filetype", "notify")
  api.nvim_buf_set_option(buf, "modifiable", true)

  notif.render(buf, notif, self.highlights)

  api.nvim_buf_set_option(buf, "modifiable", false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local width = config.minimum_width()
  for _, line in pairs(lines) do
    width = math.max(width, vim.str_utfindex(line))
  end

  self._width = width
  self._height = #lines
end

function NotificationBuf:timeout()
  return self._notif.timeout
end

function NotificationBuf:buffer()
  return self._buffer
end

function NotificationBuf:level()
  return self._notif.level
end

---@param buf number
---@param notification Notification
---@return NotificationBuf
return function(buf, notification, opts)
  return NotificationBuf:new(
    vim.tbl_extend("keep", { buffer = buf, notif = notification }, opts or {})
  )
end
