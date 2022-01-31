local util = require("notify.util")

local M = {}

---@param windows number[]
---@param direction "vertical" | "horizontal"
local function window_intervals(windows, direction)
  local win_intervals = {}
  for _, w in pairs(windows) do
    local exists, existing_conf = util.get_win_config(w)
    if exists then
      local slot_key = direction == "horizontal" and "col" or "row"
      local space_key = direction == "horizontal" and "width" or "height"
      local border_space = existing_conf.border and 2 or 0
      win_intervals[#win_intervals + 1] = {
        existing_conf[slot_key],
        existing_conf[slot_key] + existing_conf[space_key] + border_space,
      }
    end
  end
  table.sort(win_intervals, function(a, b)
    return a[1] < b[1]
  end)
  return win_intervals
end

---@param existing_wins number[]
---@param required_height number Window height including borders
function M.available_row(existing_wins, required_height)
  local next_row = vim.opt.tabline:get() == "" and 0 or 1
  local window_found = false
  for _, interval in pairs(window_intervals(existing_wins, "vertical")) do
    window_found = true
    local next_bottom = next_row + required_height
    if interval[1] <= next_bottom then
      next_row = interval[2]
    else
      break
    end
  end

  if window_found and next_row + required_height >= vim.opt.lines:get() then
    return nil
  end

  return next_row
end

function M.open_win(notif_buf, opts)
  local win = vim.api.nvim_open_win(notif_buf:buffer(), false, opts)
  vim.wo[win].winhl = "Normal:Normal,FloatBorder:Notify" .. notif_buf:level()
  vim.wo[win].wrap = false
  notif_buf:open(win)
  return win
end

return M
