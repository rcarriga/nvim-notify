local max, min = math.max, math.min
local util = require("notify.util")

local M = {}

M.DIRECTION = {
  TOP_DOWN = "top_down",
  BOTTOM_UP = "bottom_up",
  LEFT_RIGHT = "left_right",
  RIGHT_LEFT = "right_left",
}

local function is_increasing(direction)
  return (direction == M.DIRECTION.TOP_DOWN or direction == M.DIRECTION.LEFT_RIGHT)
end

local function moves_vertically(direction)
  return (direction == M.DIRECTION.TOP_DOWN or direction == M.DIRECTION.BOTTOM_UP)
end

function M.slot_name(direction)
  if moves_vertically(direction) then
    return "height"
  end
  return "width"
end

local function less(a, b)
  return a < b
end

local function greater(a, b)
  return a > b
end

local function overlaps(a, b)
  return a.min <= b.max and b.min <= a.max
end

local move_slot = function(direction, slot, delta)
  if is_increasing(direction) then
    return slot + delta
  end
  return slot - delta
end

local function slot_key(direction)
  return moves_vertically(direction) and "row" or "col"
end

local function space_key(direction)
  return moves_vertically(direction) and "height" or "width"
end

-- TODO: Use direction to check border lists
local function border_padding(direction, win_conf)
  if not win_conf.border or win_conf.border == "none" then
    return 0
  end
  return 2
end

---@param windows number[]
---@param direction string
---@return { max: integer, min: integer}[]
local function window_intervals(windows, direction, cmp)
  local win_intervals = {}
  for _, w in ipairs(windows) do
    local exists, existing_conf = util.get_win_config(w)
    if exists then
      local border_space = border_padding(direction, existing_conf)
      win_intervals[#win_intervals + 1] = {
        min = existing_conf[slot_key(direction)],
        max = existing_conf[slot_key(direction)]
          + existing_conf[space_key(direction)]
          + border_space
          - 1,
      }
    end
  end
  table.sort(win_intervals, function(a, b)
    return cmp(a.min, b.min)
  end)
  return win_intervals
end

function M.get_slot_range(direction)
  local top = vim.opt.tabline:get() == "" and 0 or 1
  local bottom = vim.opt.lines:get()
    - (vim.opt.cmdheight:get() + (vim.opt.laststatus:get() > 0 and 1 or 0))
  local left = 1
  local right = vim.opt.columns:get()
  if M.DIRECTION.TOP_DOWN == direction then
    return top, bottom
  elseif M.DIRECTION.BOTTOM_UP == direction then
    return bottom, top
  elseif M.DIRECTION.LEFT_RIGHT == direction then
    return left, right
  elseif M.DIRECTION.RIGHT_LEFT == direction then
    return right, left
  end
  error(string.format("Invalid direction: %s", direction))
end

---@param existing_wins number[] Windows to avoid overlapping
---@param required_space number Window height or width including borders
---@param direction string Direction to stack windows, one of M.DIRECTION
---@return number | nil Slot to place window at or nil if no slot available
function M.available_slot(existing_wins, required_space, direction)
  local increasing = is_increasing(direction)
  local cmp = increasing and less or greater
  local first_slot, last_slot = M.get_slot_range(direction)

  local function create_interval(start_slot)
    local end_slot = move_slot(direction, start_slot, required_space - 1)
    return { min = min(start_slot, end_slot), max = max(start_slot, end_slot) }
  end

  local interval = create_interval(first_slot)

  local intervals = window_intervals(existing_wins, direction, cmp)

  for _, next_interval in ipairs(intervals) do
    if overlaps(next_interval, interval) then
      interval = create_interval(
        move_slot(direction, increasing and next_interval.max or next_interval.min, 1)
      )
    end
  end

  if #intervals > 0 and not cmp(is_increasing and interval.max or interval.min, last_slot) then
    return nil
  end

  return interval.min
end

---Gets the next slow available for the given window while maintaining its position using the given list.
---@param win number
---@param open_windows number[]
---@param direction string
function M.slot_after_previous(win, open_windows, direction)
  local key = slot_key(direction)
  local cmp = is_increasing(direction) and less or greater
  local exists, cur_win_conf = pcall(vim.api.nvim_win_get_config, win)
  if not exists then
    return 0
  end

  local cur_slot = cur_win_conf[key][false]
  local win_confs = {}
  for _, w in ipairs(open_windows) do
    local success, conf = pcall(vim.api.nvim_win_get_config, w)
    if success then
      win_confs[w] = conf
    end
  end

  local preceding_wins = vim.tbl_filter(function(open_win)
    return win_confs[open_win] and cmp(win_confs[open_win][key][false], cur_slot)
  end, open_windows)

  if #preceding_wins == 0 then
    local start = M.get_slot_range(direction)
    if is_increasing(direction) then
      return start
    end
    return move_slot(
      direction,
      start,
      cur_win_conf[space_key(direction)] + border_padding(direction, cur_win_conf)
    )
  end

  table.sort(preceding_wins, function(a, b)
    return cmp(win_confs[a][key][false], win_confs[b][key][false])
  end)

  local last_win = preceding_wins[#preceding_wins]
  local last_win_conf = win_confs[last_win]

  if is_increasing(direction) then
    return move_slot(
      direction,
      last_win_conf[key][false],
      last_win_conf[space_key(direction)] + border_padding(direction, last_win_conf)
    )
  else
    return move_slot(
      direction,
      last_win_conf[key][false],
      cur_win_conf[space_key(direction)] + border_padding(direction, cur_win_conf)
    )
  end
end

return M
