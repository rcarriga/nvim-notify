local api = vim.api
local namespace = api.nvim_create_namespace("nvim-notify")
local animate = require("notify.animate")
local util = require("notify.util")

local WinStage = {
  OPENING = "opening",
  OPEN = "open",
  CLOSING = "closing",
}

---@class NotificationRenderer
---@field pending FIFOQueue
---@field win_states table<number, table<string, SpringState>>
---@field win_stages table<number, string>
---@field win_width table<number, number>
---@field notifications table<number, Notification>
local NotificationRenderer = {}

function NotificationRenderer:new()
  local sender = {
    win_stages = {},
    win_states = {},
    pending = util.FIFOQueue(),
    win_width = {},
    notifications = {},
  }
  self.__index = self
  setmetatable(sender, self)
  return sender
end

function NotificationRenderer:step(time)
  self:push_pending()
  if vim.tbl_isempty(self.win_stages) then
    return false
  end
  self:update_states(time)
  self:render_windows()
  self:advance_stages()
  return true
end

function NotificationRenderer:window_intervals()
  local win_intervals = {}
  for w, _ in pairs(self.win_stages) do
    local exists, existing_conf = util.get_win_config(w)
    if exists then
      win_intervals[#win_intervals + 1] = {
        existing_conf.row,
        existing_conf.row + existing_conf.height + 2,
      }
    end
  end
  table.sort(win_intervals, function(a, b)
    return a[1] < b[1]
  end)
  return win_intervals
end

function NotificationRenderer:push_pending()
  if self.pending:is_empty() then
    return
  end
  while not self.pending:is_empty() do
    local next_notif = self.pending:peek()
    local next_height = #next_notif.message + 3 -- Title and borders

    local next_row = 0
    for _, interval in pairs(self:window_intervals()) do
      local next_bottom = next_row + next_height
      if interval[1] <= next_bottom then
        next_row = interval[2]
      else
        break
      end
    end

    if next_row + next_height >= vim.opt.lines:get() then
      return
    end

    self:add_window(next_notif, next_row)
    self.pending:pop()
  end
end

function NotificationRenderer:advance_stages()
  for win, _ in pairs(self.win_stages) do
    local complete = self:is_stage_complete(win)
    if complete then
      self:advance_stage(win)
    end
  end
end

function NotificationRenderer:is_stage_complete(win)
  local stage = self.win_stages[win]
  if stage == WinStage.OPENING then
    for _, state in pairs(self.win_states[win] or {}) do
      if state.goal ~= util.round(state.position, 2) then
        return false
      end
    end
  end
  if stage == WinStage.OPEN then
    return false -- Updated by timer
  end
  if stage == WinStage.CLOSING then
    if self.win_states[win].width.position >= 2 then
      return false
    end
  end
  return true
end

function NotificationRenderer:advance_stage(win)
  local cur_stage = self.win_stages[win]
  if cur_stage == WinStage.OPENING then
    self.win_stages[win] = WinStage.OPEN
    local function close()
      if api.nvim_get_current_win() ~= win then
        return self:advance_stage(win)
      end
      vim.defer_fn(close, 1000)
    end
    vim.defer_fn(close, self.notifications[win].timeout)
  elseif cur_stage == WinStage.OPEN then
    self.win_stages[win] = WinStage.CLOSING
  else
    local success = pcall(api.nvim_win_close, win, true)
    if not success then
      self:remove_win_state(win)
      return
    end
    local notif = self.notifications[win]
    self:remove_win_state(win)
    if notif.on_close then
      notif.on_close(win)
    end
  end
end

function NotificationRenderer:remove_win_state(win)
  self.win_stages[win] = nil
  self.win_states[win] = nil
  self.notifications[win] = nil
end

function NotificationRenderer:update_states(time)
  local updated_states = {}
  for win, _ in pairs(self.win_stages) do
    local states = self:stage_state(win)
    if states then
      updated_states[win] = vim.tbl_map(function(state)
        return animate.spring(time, state)
      end, states)
    end
  end
  self.win_states = updated_states
end

function NotificationRenderer:stage_state(win)
  local cur_state = self.win_states[win] or {}
  local exists, win_conf = util.get_win_config(win)
  if not exists then
    self:remove_win_state(win)
    return
  end
  local new_state = {}
  local goals = self:stage_goals(win)
  for field, goal in pairs(goals) do
    local cur_field_state = cur_state[field] or {}
    local cur_stage = self.win_stages[win]
    new_state[field] = {
      position = cur_field_state.position or win_conf[field],
      velocity = cur_field_state.velocity,
      goal = goal,
      frequency = 2,
      damping = cur_stage == WinStage.CLOSING and 0.6 or 1,
    }
  end
  return new_state
end

function NotificationRenderer:stage_goals(win)
  local create_goals = ({
    [WinStage.OPENING] = function()
      return {
        width = self.win_width[win],
        col = vim.opt.columns:get(),
      }
    end,
    [WinStage.OPEN] = function()
      return {
        col = vim.opt.columns:get(),
      }
    end,
    [WinStage.CLOSING] = function()
      return {
        width = 1,
        col = vim.opt.columns:get(),
      }
    end,
  })[self.win_stages[win]]

  return create_goals()
end

function NotificationRenderer:render_windows()
  for win, states in pairs(self.win_states) do
    local exists, conf = util.get_win_config(win)
    if exists then
      for field, state in pairs(states) do
        conf[field] = state.position
      end
      util.set_win_config(win, conf)
    else
      self:remove_win_state(win)
    end
  end
end

---@param notif Notification
function NotificationRenderer:add_window(notif, row)
  local buf = vim.api.nvim_create_buf(false, true)
  local message_line = 0
  local right_title = vim.fn.strftime("%H:%M", notif.time)
  local left_title = " " .. notif.icon .. " " .. (notif.title or "")
  local win_width = math.max(
    math.max(unpack(vim.tbl_map(function(line)
      return vim.fn.strchars(line)
    end, notif.message))),
    vim.fn.strchars(left_title .. right_title),
    50
  )
  if notif.title then
    message_line = 2
    local title_line = left_title
      .. string.rep(" ", win_width - vim.fn.strchars(left_title .. right_title))
      .. right_title
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { title_line, string.rep("━", win_width) })
    vim.api.nvim_buf_add_highlight(buf, namespace, "Notify" .. notif.level .. "Title", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, namespace, "Notify" .. notif.level, 1, 0, -1)
  end
  vim.api.nvim_buf_set_lines(buf, message_line, message_line + #notif.message, false, notif.message)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local win_opts = {
    relative = "editor",
    anchor = "NE",
    width = 1,
    height = message_line + #notif.message,
    col = vim.opt.columns:get(),
    row = row,
    border = "rounded",
    style = "minimal",
  }

  local win = vim.api.nvim_open_win(buf, false, win_opts)
  vim.wo[win].winhl = "Normal:Normal,FloatBorder:Notify" .. notif.level
  vim.wo[win].wrap = false

  self.win_stages[win] = WinStage.OPENING
  self.win_width[win] = win_width
  self.notifications[win] = notif
  if notif.on_open then
    notif.on_open(win)
  end
end

---@param notif Notification
function NotificationRenderer:queue(notif)
  self.pending:push(notif)
end

---@return NotificationRenderer
return function()
  return NotificationRenderer:new()
end
