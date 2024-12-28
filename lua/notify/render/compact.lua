local base = require("notify.render.base")

return function(bufnr, notif, highlights)
  local namespace = base.namespace()
  local icon = notif.icon
  local title = notif.title[1]

  if type(title) == "string" and notif.duplicates then
    title = string.format("%s x%d", title, #notif.duplicates)
  end

  local prefix
  if type(title) == "string" and #title > 0 then
    prefix = string.format("%s | %s:", icon, title)
  else
    prefix = string.format("%s |", icon)
  end
  local message = {
    string.format("%s %s", prefix, notif.message[1]),
    unpack(notif.message, 2),
  }

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, message)

  local icon_length = string.len(icon)
  local prefix_length = string.len(prefix)

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
    end_line = #message,
    priority = 50,
  })
end
