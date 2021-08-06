local api = vim.api
local namespace = api.nvim_create_namespace("nvim-notify")

---@class NotificationBuf
---@field _notif Notification
---@field _state "open" | "closed"
---@field _buffer number
---@field _height number
---@field _width number
local NotificationBuf = {}

local BufState = {
  OPEN = "open",
  CLOSED = "close",
}

function NotificationBuf:new(kwargs)
  local notif_buf = {
    _notif = kwargs.notif,
    _buffer = kwargs.buffer,
    _state = BufState.CLOSED,
    _width = 0,
    _height = 0,
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
  if self._notif.on_open then
    self._notif.on_open(win)
  end
end

function NotificationBuf:close(win)
  if self._state ~= BufState.OPEN then
    return
  end
  self._state = BufState.CLOSED
  if self._notif.on_close then
    self._notif.on_close(win)
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

  api.nvim_buf_set_option(buf, "modifiable", true)

  local right_title = vim.fn.strftime("%H:%M", notif.time)
  local left_title = " " .. notif.icon .. " " .. (notif.title or "")
  local max_width = math.max(
    math.max(unpack(vim.tbl_map(function(line)
      return vim.fn.strchars(line)
    end, notif.message))),
    vim.fn.strchars(left_title .. right_title),
    50
  )
  local title_highlight = "Notify" .. notif.level .. "Title"
  api.nvim_buf_set_lines(buf, 0, 1, false, { "", "" })
  api.nvim_buf_set_extmark(buf, namespace, 0, 0, {
    virt_text = { { left_title, title_highlight } },
    virt_text_win_col = 0,
    priority = max_width,
  })
  api.nvim_buf_set_extmark(buf, namespace, 0, 0, {
    virt_text = { { right_title, title_highlight } },
    virt_text_pos = "right_align",
    priority = max_width,
  })
  api.nvim_buf_set_extmark(buf, namespace, 1, 0, {
    virt_text = { { string.rep("━", max_width), "Notify" .. notif.level } },
    virt_text_win_col = 0,
    priority = max_width,
  })
  api.nvim_buf_set_extmark(buf, namespace, 1, 0, {
    virt_text = { { string.rep("━", max_width), "Notify" .. notif.level } },
    virt_text_win_col = 0,
    priority = max_width,
  })

  api.nvim_buf_set_lines(buf, 2, 2 + #notif.message, false, notif.message)
  api.nvim_buf_set_option(buf, "modifiable", false)

  self._width = max_width
  self._height = 2 + #notif.message
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
return function(buf, notification)
  return NotificationBuf:new({ buffer = buf, notif = notification })
end
