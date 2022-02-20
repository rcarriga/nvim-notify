local api = vim.api
local config = require("notify.config")
local namespace = api.nvim_create_namespace("nvim-notify")

return function(bufnr, notif, highlights)
  local left_icon = notif.icon .. " "
  local max_width = math.max(
    math.max(unpack(vim.tbl_map(function(line)
      return vim.fn.strchars(line)
    end, notif.message))),
    config.minimum_width()
  )
  local left_title = notif.title[1] .. string.rep(" ", max_width)
  local right_title = notif.title[2]
  api.nvim_buf_set_lines(bufnr, 0, 1, false, { "", "" })
  api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_text = {
      { " " },
      { left_icon, highlights.icon },
      { left_title, highlights.title },
    },
    virt_text_win_col = 0,
    priority = max_width,
  })
  api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_text = { { right_title, highlights.title }, { " " } },
    virt_text_pos = "right_align",
    priority = max_width,
  })
  api.nvim_buf_set_extmark(bufnr, namespace, 1, 0, {
    virt_text = { { string.rep("━", max_width), highlights.border } },
    virt_text_win_col = 0,
    priority = max_width,
  })
  api.nvim_buf_set_lines(bufnr, 2, -1, false, notif.message)

  api.nvim_buf_set_extmark(bufnr, namespace, 2, 0, {
    hl_group = highlights.body,
    end_line = 1 + #notif.message,
    end_col = #notif.message[#notif.message],
  })
end
