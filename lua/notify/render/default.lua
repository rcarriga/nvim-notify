local api = vim.api
local base = require("notify.render.base")
local util = require("notify.util")

return function(bufnr, notif, highlights, config)
  local left_icon = notif.icon == "" and "" or notif.icon .. " "
  local max_message_width = util.max_line_width(notif.message)

  local right_title = notif.title[2]
  local left_title = notif.title[1]
  if notif.duplicates then
    left_title = string.format("%s (x%d)", left_title, #notif.duplicates)
  end
  local title_accum = vim.api.nvim_strwidth(left_icon)
    + vim.api.nvim_strwidth(right_title)
    + vim.api.nvim_strwidth(left_title)

  local left_buffer = string.rep(" ", math.max(0, max_message_width - title_accum))

  local namespace = base.namespace()
  api.nvim_buf_set_lines(bufnr, 0, 1, false, { "", "" })

  local virt_text = left_icon == "" and {} or { { " " }, { left_icon, highlights.icon } }
  table.insert(virt_text, { left_title .. left_buffer, highlights.title })
  api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_text = virt_text,
    virt_text_win_col = 0,
    priority = 10,
  })
  api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_text = { { " " }, { right_title, highlights.title }, { " " } },
    virt_text_pos = "right_align",
    priority = 10,
  })
  api.nvim_buf_set_extmark(bufnr, namespace, 1, 0, {
    virt_text = {
      {
        string.rep(
          "━",
          math.max(vim.api.nvim_strwidth(left_buffer) + title_accum + 2, config.minimum_width())
        ),
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
    priority = 50, -- Allow treesitter to override
  })
end
