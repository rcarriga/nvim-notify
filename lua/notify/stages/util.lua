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

---@param windows number[]
---@param direction integer
local function window_intervals(windows, direction, cmp)
  local win_intervals = {}
  for _, w in pairs(windows) do
    local exists, existing_conf = util.get_win_config(w)
    if exists then
      local slot_key = (direction == M.DIRECTION.LEFT_RIGHT or direction == M.DIRECTION.RIGHT_LEFT)
          and "col"
        or "row"
      local space_key = (direction == M.DIRECTION.LEFT_RIGHT or direction == M.DIRECTION.RIGHT_LEFT)
          and "width"
        or "height"
      local border_space = existing_conf.border and 2 or 0
      win_intervals[#win_intervals + 1] = {
        existing_conf[slot_key],
        existing_conf[slot_key] + existing_conf[space_key] + border_space,
      }
    end
  end
  table.sort(win_intervals, function(a, b)
    return cmp(a[1], b[1])
  end)
  return win_intervals
end

local function get_slot_range(direction)
  local top = vim.opt.tabline:get() == "" and 0 or 1
  local bottom = vim.opt.lines:get() - (vim.opt.laststatus:get() > 0 and 2 or 1)
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

  local first_slot, last_slot = get_slot_range(direction)

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

return M
