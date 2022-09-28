local api = vim.api
local base = require("notify.render.base")

return function(bufnr, notif, highlights, config)
  local max_message_width = math.max(math.max(unpack(vim.tbl_map(function(line)
    return vim.fn.strchars(line)
  end, notif.message))))
  local title = notif.title[1]
  local title_accum = vim.str_utfindex(title)

  local title_buffer = string.rep(
    " ",
    (math.max(max_message_width, title_accum, config.minimum_width()) - title_accum) / 2
  )

  local namespace = base.namespace()

  api.nvim_buf_set_lines(bufnr, 0, 1, false, { "", "" })
  api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_text = {
      { title_buffer .. title .. title_buffer, highlights.title },
    },
    virt_text_win_col = 0,
    priority = 10,
  })
  api.nvim_buf_set_extmark(bufnr, namespace, 1, 0, {
    virt_text = {
      {
        string.rep("━", math.max(max_message_width, title_accum, config.minimum_width())),
        highlights.border,
      },
    },
    virt_text_win_col = 0,
    priority = 10,
  })
  api.nvim_buf_set_lines(bufnr, 2, -1, false, notif.message)

  api.nvim_buf_set_extmark(bufnr, namespace, 2, 0, {
    hl_group = highlights.body,
    end_line = 1 + #notif.message,
    end_col = #notif.message[#notif.message],
    priority = 50,
  })
end
