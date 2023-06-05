local api = vim.api

local NotifyBufHighlights = require("notify.service.buffer.highlights")

---@class NotificationBuf
---@field highlights NotifyBufHighlights
---@field _config table
---@field _notif notify.Notification
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
    _config = kwargs.config,
    _max_width = kwargs.max_width,
    _buffer = kwargs.buffer,
    _state = BufState.CLOSED,
    _width = 0,
    _height = 0,
  }
  setmetatable(notif_buf, self)
  self.__index = self
  notif_buf:set_notification(kwargs.notif)
  return notif_buf
end

function NotificationBuf:set_notification(notif)
  self._notif = notif
  self:_create_highlights()
end

function NotificationBuf:_create_highlights()
  local existing_opacity = self.highlights and self.highlights.opacity or 100
  self.highlights = NotifyBufHighlights(self._notif.level, self._buffer, self._config)
  if existing_opacity < 100 then
    self.highlights:set_opacity(existing_opacity)
  end
end

function NotificationBuf:open(win)
  if self._state ~= BufState.CLOSED then
    return
  end
  self._state = BufState.OPEN
  local record = self._notif:record()
  if self._notif.on_open then
    self._notif.on_open(win, record)
  end
  if self._config.on_open() then
    self._config.on_open()(win, record)
  end
end

function NotificationBuf:should_animate()
  return self._notif.animate
end

function NotificationBuf:close(win)
  if self._state ~= BufState.OPEN then
    return
  end
  self._state = BufState.CLOSED
  vim.schedule(function()
    if self._notif.on_close then
      self._notif.on_close(win)
    end
    if self._config.on_close() then
      self._config.on_close()(win)
    end
    pcall(api.nvim_buf_delete, self._buffer, { force = true })
  end)
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

  local render_namespace = require("notify.render.base").namespace()
  api.nvim_buf_set_option(buf, "filetype", "notify")
  api.nvim_buf_set_option(buf, "modifiable", true)
  api.nvim_buf_clear_namespace(buf, render_namespace, 0, -1)

  notif.render(buf, notif, self.highlights, self._config)

  api.nvim_buf_set_option(buf, "modifiable", false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local width = self._config.minimum_width()
  for _, line in pairs(lines) do
    width = math.max(width, vim.str_utfindex(line))
  end
  local success, extmarks =
    pcall(api.nvim_buf_get_extmarks, buf, render_namespace, 0, #lines, { details = true })
  if not success then
    extmarks = {}
  end
  local virt_texts = {}
  for _, mark in ipairs(extmarks) do
    local details = mark[4]
    for _, virt_text in ipairs(details.virt_text or {}) do
      virt_texts[mark[2]] = (virt_texts[mark[2]] or "") .. virt_text[1]
    end
  end
  for _, text in pairs(virt_texts) do
    width = math.max(width, vim.str_utfindex(text))
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

function NotificationBuf:is_valid()
  return self._buffer and vim.api.nvim_buf_is_valid(self._buffer)
end

function NotificationBuf:level()
  return self._notif.level
end

---@param buf number
---@param notification notify.Notification;q
---@return NotificationBuf
return function(buf, notification, opts)
  return NotificationBuf:new(
    vim.tbl_extend("keep", { buffer = buf, notif = notification }, opts or {})
  )
end
