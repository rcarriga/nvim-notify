local util = require("notify.util")

local M = {}

M.DIRECTION = {
  TOP_DOWN = "top_down",
  BOTTOM_UP = "bottom_up",
  LEFT_RIGHT = "left_right",
  RIGHT_LEFT = "right_left",
}

function M.slot_name(direction)
  if direction == M.DIRECTION.TOP_DOWN or direction == M.DIRECTION.BOTTOM_UP then
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

local function overlaps(x1, x2, y1, y2)
  return math.min(x1, x2) <= math.max(y1, y2) and math.min(y1, y2) <= math.max(x1, x2)
end

local move_slot = function(direction, slot, delta)
  if M.DIRECTION.TOP_DOWN == direction or M.DIRECTION.LEFT_RIGHT == direction then
    return slot + delta
  end
  return slot - delta
end

local function slot_key(direction)
  return (direction == M.DIRECTION.LEFT_RIGHT or direction == M.DIRECTION.RIGHT_LEFT) and "col"
    or "row"
end

local function space_key(direction)
  return (direction == M.DIRECTION.LEFT_RIGHT or direction == M.DIRECTION.RIGHT_LEFT) and "width"
    or "height"
end

---@param windows number[]
---@param direction integer
local function window_intervals(windows, direction, cmp)
  local win_intervals = {}
  for _, w in pairs(windows) do
    local exists, existing_conf = util.get_win_config(w)
    if exists then
      local border_space = existing_conf.border and 2 or 0
      win_intervals[#win_intervals + 1] = {
        existing_conf[slot_key(direction)],
        existing_conf[slot_key(direction)] + existing_conf[space_key(direction)] + border_space,
      }
    end
  end
  table.sort(win_intervals, function(a, b)
    return cmp(a[1], b[1])
  end)
  return win_intervals
end

function M.get_slot_range(direction)
  local top = vim.opt.tabline:get() == "" and 0 or 1
  local bottom = vim.opt.lines:get()
    - (vim.opt.cmdheight:get() + (vim.opt.laststatus:get() > 0 and 2 or 1))
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
---@param direction integer Direction to stack windows, one of M.DIRECTION
---@return number | nil Slot to place window at or nil if no slot available
function M.available_slot(existing_wins, required_space, direction)
  local cmp = (direction == M.DIRECTION.LEFT_RIGHT or direction == M.DIRECTION.TOP_DOWN) and less
    or greater

  local first_slot, last_slot = M.get_slot_range(direction)

  local next_slot = first_slot

  local next_end_slot = move_slot(direction, next_slot, required_space)
  local window_found = false

  local intervals = window_intervals(existing_wins, direction, cmp)

  for _, interval in ipairs(intervals) do
    window_found = true
    if overlaps(interval[1], interval[2], next_slot, next_end_slot) then
      next_slot = next_slot > next_end_slot and interval[1] or interval[2]
      next_end_slot = move_slot(direction, next_slot, required_space)
    end
  end

  if window_found and not cmp(next_end_slot, last_slot) then
    return nil
  end

  local res = math.min(next_slot, next_end_slot)
  return res
end

local warned = false
function M.available_row(wins, required_space)
  if not warned then
    vim.notify(
      [[`available_row` function for stages is deprecated, 
use `available_slot` instead with a direction
```lua
available_slot(existing_wins, required_space, stages_util.DIRECTION.TOP_DOWN)
```
]],
      "warn",
      {
        on_open = function(win)
          vim.api.nvim_buf_set_option(vim.api.nvim_win_get_buf(win), "filetype", "markdown")
        end,
        title = "nvim-notify",
      }
    )
    warned = true
  end
  return M.available_slot(wins, required_space, M.DIRECTION.TOP_DOWN)
end

---Gets the next slow available for the given window while maintaining its position using the given list.
---@param win number
---@param open_windows number[]
---@param direction string
function M.slot_after_previous(win, open_windows, direction)
  local key = slot_key(direction)
  local cmp = (direction == M.DIRECTION.LEFT_RIGHT or direction == M.DIRECTION.TOP_DOWN) and less
    or greater
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

  local higher_wins = vim.tbl_filter(function(open_win)
    return win_confs[open_win] and cmp(win_confs[open_win][key][false], cur_slot)
  end, open_windows)

  if #higher_wins == 0 then
    local first_slot = M.get_slot_range(direction)
    if direction == M.DIRECTION.RIGHT_LEFT or direction == M.DIRECTION.BOTTOM_UP then
      return move_slot(direction, first_slot, cur_win_conf[space_key(direction)])
    end
    return first_slot
  end

  table.sort(higher_wins, function(a, b)
    return cmp(win_confs[a][key][false], win_confs[b][key][false])
  end)

  local last_win = higher_wins[#higher_wins]
  local last_win_conf = win_confs[last_win]
  local res = move_slot(
    direction,
    last_win_conf[key][false],
    last_win_conf[space_key(direction)] + (last_win_conf.border ~= "none" and 2 or 0)
  )
  return res
end

return M
