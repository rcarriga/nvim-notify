local base = require("notify.render.base")

return function(bufnr, notif, highlights)
  local namespace = base.namespace()
  local icon = notif.icon
  local title = notif.title[1]

  local prefix
  if type(title) == "string" and #title > 0 then
    prefix = string.format("%s | %s:", icon, title)
  else
    prefix = string.format("%s |", icon)
  end
  notif.message[1] = string.format("%s %s", prefix, notif.message[1])

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, notif.message)

  local icon_length = vim.str_utfindex(icon)
  local prefix_length = vim.str_utfindex(prefix)

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
