local api = vim.api
local base = require("notify.render.base")

return function(bufnr, notif, highlights)
  local namespace = base.namespace()
  api.nvim_buf_set_lines(bufnr, 0, -1, false, notif.message)

  api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    hl_group = highlights.icon,
    end_line = #notif.message - 1,
    end_col = #notif.message[#notif.message],
    priority = 50,
  })
end
