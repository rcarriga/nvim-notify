local NotificationBuf = require("notify.service.buffer")
local util = require("notify.util")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local entry_display = require("telescope.pickers.entry_display")
local notify = require("notify")

local widths = {
  time = 8,
  title = nil,
  icon = nil,
  level = nil,
  message = nil,
}

local displayer = entry_display.create({
  separator = " ",
  items = {
    { width = widths.time },
    { width = widths.title },
    { width = widths.icon },
    { width = widths.level },
    { width = widths.message },
  },
})

local telescope_notifications = function(opts)
  local notifs = require("notify").history()
  local reversed = {}
  for i, notif in ipairs(notifs) do
    reversed[#notifs - i + 1] = notif
  end
  pickers.new(opts, {
    results_title = "Notifications",
    prompt_title = "Filter Notifications",
    finder = finders.new_table({
      results = reversed,
      entry_maker = function(notif)
        return {
          value = notif,
          display = function(entry)
            return displayer({
              { vim.fn.strftime("%T", entry.value.time), "NotifyLogTime" },
              { entry.value.title[1], "NotifyLogTitle" },
              { entry.value.icon, "Notify" .. entry.value.level .. "Title" },
              { entry.value.level, "Notify" .. entry.value.level .. "Title" },
              { entry.value.message[1], "Normal" },
            })
          end,
          ordinal = notif.title[1] .. " " .. notif.title[2] .. " " .. table.concat(
            notif.message,
            " "
          ),
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local notification = selection.value
        local buf = vim.api.nvim_create_buf(false, true)
        local notif_buf = NotificationBuf(buf, notification, { config = notify._config() })
        notif_buf:render()

        local height = notif_buf:height()
        local width = notif_buf:width()

        local lines = vim.opt.lines:get()
        local cols = vim.opt.columns:get()

        util.open_win(notif_buf, true, {
          relative = "editor",
          row = (lines - height) / 2,
          col = (cols - width) / 2,
          height = height,
          width = width,
          border = "rounded",
          style = "minimal",
        })
      end)
      return true
    end,
    previewer = previewers.new_buffer_previewer({
      title = "Message",
      define_preview = function(self, entry, status)
        local notification = entry.value
        local max_width = vim.api.nvim_win_get_config(status.preview_win).width
        local notif_buf = NotificationBuf(
          self.state.bufnr,
          notification,
          { max_width = max_width, config = notify._config() }
        )
        notif_buf:render()
      end,
    }),
  }):find()
end

return require("telescope").register_extension({
  exports = {
    notify = telescope_notifications,
  },
})
