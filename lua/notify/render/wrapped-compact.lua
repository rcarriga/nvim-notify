-- WRAPS TEXT AND ADDS SOME PADDING.
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
    next_line, line = line:sub(1, width), line:sub(width + 1)
    text[#text + 1] = next_line
  end
end

---@param lines string[]
---@param max_width number
---@return string[]
local function custom_wrap(lines, max_width)
  local right_pad = "  "
  local wrapped_lines = {}
  for _, line in pairs(lines) do
    local new_lines = split_length(line, max_width - #right_pad)
    for _, nl in ipairs(new_lines) do
      table.insert(wrapped_lines, nl:gsub("^%s+", "") .. right_pad)
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
  local icon_length = #icon
  local prefix = ""
  local prefix_length = 0
  local message = custom_wrap(notif.message, config.max_width() or 80)
  local title = notif.title[1]
  local default_titles = { "Error", "Warning", "Notify" }
  local has_valid_manual_title = type(title) == "string"
    and #title > 0
    and not vim.tbl_contains(default_titles, title)

  if has_valid_manual_title then
    prefix = string.format("%s %s ", icon, title)
    if notif.duplicates then
      prefix = string.format("%s x%d", prefix, #notif.duplicates)
    end
    prefix_length = #prefix
    table.insert(message, 1, prefix)
  end

  message[1] = " " .. message[1]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, message)

  if has_valid_manual_title then
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
  end

  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, prefix_length + 1, {
    hl_group = highlights.body,
    end_line = #message,
    priority = 50,
  })

  -- padding to the left/right
  for ln = 1, #message do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, ln, 0, {
      virt_text = { { " ", highlights.body } },
      virt_text_pos = "inline",
    })
    vim.api.nvim_buf_set_extmark(bufnr, namespace, ln, 0, {
      virt_text = { { " ", highlights.body } },
      virt_text_pos = "right_align",
    })
  end
end
