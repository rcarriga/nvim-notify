local vim_api = vim.api
local base = require("notify.render.base")

---@param line string
---@param width number
---@return table
local function split_length(line, width)
  local text = {}
  local next_line
  while true do
    if #line == 0 then
      return text
    end
    next_line, line = line:sub(1, width), line:sub(width + 1)
    text[#text + 1] = next_line
  end
end

---@param lines string[]
---@param max_width number
---@return table
local function custom_wrap(lines, max_width)
  local wrapped_lines = {}
  for _, line in pairs(lines) do
    local new_lines = split_length(line, max_width)
    for _, nl in ipairs(new_lines) do
      nl = nl:gsub("^%s*", " "):gsub("%s*$", " ")
      table.insert(wrapped_lines, nl)
    end
  end
  return wrapped_lines
end

---@param bufnr number
---@param notif notify.Record
---@param highlights notify.Highlights
---@param config notify.Config
return function(bufnr, notif, highlights, config)
  local namespace = base.namespace()
  local icon = notif.icon .. " "
  local title = notif.title[1] or "Notify"

  local terminal_width = vim.o.columns
  local default_max_width = math.floor((terminal_width * 30) / 100)
  local max_width = config.max_width and config.max_width() or default_max_width

  -- Ensure max_width is within bounds
  max_width = math.max(10, math.min(max_width, terminal_width - 1))

  local message = custom_wrap(notif.message, max_width)

  local prefix = string.format(" %s %s", icon, title)
  table.insert(message, 1, prefix)
  table.insert(message, 2, string.rep("━", max_width))

  vim_api.nvim_buf_set_lines(bufnr, 0, -1, false, message)

  local prefix_length = vim.str_utfindex(prefix)
  prefix_length = math.min(prefix_length, max_width - 1)

  vim_api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_text = {
      { " " },
      { icon, highlights.icon },
      { title, highlights.title },
      { " " },
    },
    virt_text_win_col = 0,
    priority = 10,
  })

  vim_api.nvim_buf_set_extmark(bufnr, namespace, 1, 0, {
    virt_text = {
      { string.rep("━", max_width), highlights.border },
    },
    virt_text_win_col = 0,
    priority = 10,
  })

  vim_api.nvim_buf_set_extmark(bufnr, namespace, 2, 0, {
    hl_group = highlights.body,
    end_line = #message,
    end_col = 0,
    priority = 50,
  })
end
