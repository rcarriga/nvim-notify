local config = require("notify.config")
local api = vim.api
local animate = require("notify.animate")
local util = require("notify.util")

---@class WindowAnimator
---@field win_states table<number, table<string, SpringState>>
---@field win_stages table<number, string>
---@field notif_bufs table<number, NotificationBuf>
---@field timed table
---@field stages table
local WindowAnimator = {}

function WindowAnimator:new(stages)
  local animator = {
    win_stages = {},
    win_states = {},
    notif_bufs = {},
    timed = {},
    stages = stages,
  }
  self.__index = self
  setmetatable(animator, self)
  return animator
end

function WindowAnimator:render(queue, time)
  self:push_pending(queue)
  if vim.tbl_isempty(self.win_stages) then
    return nil
  end
  local goals = self:get_goals()
  self:update_states(time, goals)
  self:advance_stages(goals)
  return self:apply_updates()
end

function WindowAnimator:push_pending(queue)
  if queue:is_empty() then
    return
  end
  while not queue:is_empty() do
    ---@type NotificationBuf
    local notif_buf = queue:peek()
    local windows = vim.tbl_keys(self.win_stages)
    local win_opts = self.stages[1]({
      message = self._get_dimensions(notif_buf),
      open_windows = windows,
    })
    if not win_opts then
      return
    end
    local opacity = util.pop(win_opts, "opacity")
    if opacity then
      notif_buf.highlights:set_opacity(opacity)
    end
    win_opts.noautocmd = true
    local win = util.open_win(notif_buf, false, win_opts)
    self.win_stages[win] = 2
    self.notif_bufs[win] = notif_buf
    notif_buf:open(win)
    queue:pop()
  end
end

function WindowAnimator:advance_stages(goals)
  local default_complete = function(goal, position)
    return goal == util.round(position, 2)
  end
  for win, _ in pairs(self.win_stages) do
    local win_goals = goals[win]
    local complete = true
    for field, state in pairs(self.win_states[win] or {}) do
      if win_goals[field].complete then
        complete = win_goals[field].complete(state.position)
      else
        complete = default_complete(state.goal, state.position)
      end
      if not complete then
        break
      end
    end
    if complete and not win_goals.time then
      self:advance_stage(win)
    end
  end
end

function WindowAnimator:advance_stage(win)
  local cur_stage = self.win_stages[win]
  if not cur_stage then
    return
  end
  if cur_stage < #self.stages then
    if api.nvim_get_current_win() == win then
      return
    end
    self.win_stages[win] = cur_stage + 1
    return
  end

  self.win_stages[win] = nil

  local function close()
    if api.nvim_get_current_win() == win then
      return vim.defer_fn(close, 1000)
    end
    self:remove_win(win)
  end

  close()
end

function WindowAnimator:remove_win(win)
  pcall(api.nvim_win_close, win, true)
  self.win_stages[win] = nil
  self.win_states[win] = nil
  local notif_buf = self.notif_bufs[win]
  self.notif_bufs[win] = nil
  notif_buf:close(win)
end

function WindowAnimator:update_states(time, goals)
  local updated_states = {}

  for win, win_goals in pairs(goals) do
    if win_goals.time and not self.timed[win] then
      local buf_time = self.notif_bufs[win]:timeout()
      if buf_time ~= false then
        if buf_time == true then
          buf_time = nil
        end
        self.timed[win] = true
        local timer_func = function()
          self.timed[win] = nil
          local notif_buf = self.notif_bufs[win]
          if notif_buf and notif_buf:should_stay() then
            return
          end
          self:advance_stage(win)
        end
        vim.defer_fn(timer_func, buf_time or config.default_timeout())
      end
    end

    updated_states[win] = self:stage_state(win, win_goals, time)
  end

  self.win_states = updated_states
end

function WindowAnimator:stage_state(win, goals, time)
  local cur_state = self.win_states[win] or {}

  local exists, win_conf = util.get_win_config(win)
  if not exists then
    self:remove_win(win)
    return
  end

  local new_state = {}
  for field, goal in pairs(goals) do
    if field ~= "time" then
      local goal_type = type(goal)
      -- Handle spring goal
      if goal_type == "table" and goal[1] then
        local init_state = (
            field == "opacity" and self.notif_bufs[win].highlights:get_opacity() or win_conf[field]
          )
        local cur_field_state = cur_state[field] or {}
        new_state[field] = animate.spring(time, {
          position = cur_field_state.position or init_state,
          velocity = cur_field_state.velocity,
          goal = goal[1],
        }, {
          frequency = goal.frequency or 1,
          damping = goal.damping or 1,
        })
        --- Directly move goal
      elseif goal_type ~= "table" then
        new_state[field] = { position = goal }
      else
        print("nvim-notify: Invalid stage goal: " .. vim.inspect(goal))
      end
    end
  end
  return new_state
end

function WindowAnimator:get_goals()
  local goals = {}
  local open_windows = vim.tbl_keys(self.win_stages)
  for win, win_stage in pairs(self.win_stages) do
    local notif_buf = self.notif_bufs[win]
    local win_goals = self.stages[win_stage]({
      message = self._get_dimensions(notif_buf),
      open_windows = open_windows,
    }, win)
    if not win_goals then
      self:remove_win(win)
    else
      goals[win] = win_goals
    end
  end
  return goals
end

function WindowAnimator._get_dimensions(notif_buf)
  return {
    height = math.min(config.max_height() or 1000, notif_buf:height()),
    width = math.min(config.max_width() or 1000, notif_buf:width()),
  }
end

function WindowAnimator:apply_updates()
  local updates = {}
  for win, states in pairs(self.win_states) do
    updates[win] = {}
    for field, state in pairs(states) do
      if field == "opacity" then
        self.notif_bufs[win].highlights:set_opacity(state.position)
      else
        updates[win][field] = state.position
      end
    end
  end
  if vim.tbl_isempty(updates) then
    return false
  end
  util.update_configs(updates)
  return true
end

---@return WindowAnimator
return function(stages)
  return WindowAnimator:new(stages)
end
