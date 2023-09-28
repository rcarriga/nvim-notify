-- alternative compact renderer for nvim-notify.
-- Wraps text and adds some padding (only really to the left, since padding to
-- the right is somehow not display correctly).
-- Modified version of https://github.com/rcarriga/nvim-notify/blob/master/lua/notify/render/compact.lua
--------------------------------------------------------------------------------

---@param line string
---@param width number
---@return string[]
local function split_length(line, width)
  local text = {}
  local next_line
  while true do
    if #line == 0 then
      return text
    end
    next_line, line = line:sub(1, width), line:sub(width)
    text[#text + 1] = next_line
  end
end

---@param lines string[]
---@param max_width number
---@return string[]
local function custom_wrap(lines, max_width)
  local wrapped_lines = {}
  for _, line in pairs(lines) do
    local new_lines = split_length(line, max_width)
    for _, nl in ipairs(new_lines) do
      nl = nl:gsub("^%s*", " "):gsub("%s*$", " ") -- ensure padding
      table.insert(wrapped_lines, nl)
    end
  end
  return wrapped_lines
end

---@param bufnr number
---@param notif object
---@param highlights object
---@param config object plugin config_obj
return function(bufnr, notif, highlights, config)
  local namespace = require("notify.render.base").namespace()
  local icon = notif.icon
  local title = notif.title[1]
  local prefix

  -- wrap the text & add spacing
  local max_width = config.max_width()
  if max_width == nil then
    max_width = 80
  end
  notif.message = custom_wrap(notif.message, max_width)

  local default_titles = { "Error", "Warning", "Notify" }
  local has_valid_manual_title = type(title) == "string"
    and #title > 0
    and not vim.tbl_contains(default_titles, title)

  if has_valid_manual_title then
    -- has title = icon + title as header row
    prefix = string.format(" %s %s", icon, title)
    table.insert(notif.message, 1, prefix)
  else
    -- no title = prefix the icon
    prefix = string.format(" %s", icon)
    notif.message[1] = string.format("%s %s", prefix, notif.message[1])
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, notif.message)

  local icon_length = vim.str_utfindex(icon)
  local prefix_length = vim.str_utfindex(prefix) + 1

  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    hl_group = highlights.icon,
    end_col = icon_length + 1,
    priority = 50,
  })
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, icon_length + 1, {
    hl_group = highlights.title,
    end_col = prefix_length + 1,
    priority = 50,
  })
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, prefix_length + 1, {
    hl_group = highlights.body,
    end_line = #notif.message,
    priority = 50,
  })
end
