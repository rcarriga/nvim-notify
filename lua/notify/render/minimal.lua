local api = vim.api
local base = require("notify.render.base")

return function(bufnr, notif, highlights)
  local message = notif.message
  if notif.duplicates then
    message = {
      string.format("x%d %s", #notif.duplicates, notif.message[1]),
      unpack(notif.message, 2),
    }
  end

  local namespace = base.namespace()
  api.nvim_buf_set_lines(bufnr, 0, -1, false, message)

  api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    hl_group = highlights.icon,
    end_line = #message - 1,
    end_col = #message[#message],
    priority = 50,
  })
end
