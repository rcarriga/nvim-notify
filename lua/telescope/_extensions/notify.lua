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
  local time_format = require("notify")._config().time_formats().notification
  local notifs = require("notify").history()
  local reversed = {}
  for i, notif in ipairs(notifs) do
    reversed[#notifs - i + 1] = notif
  end
  pickers
    .new(opts, {
      results_title = "Notifications",
      prompt_title = "Filter Notifications",
      finder = finders.new_table({
        results = reversed,
        entry_maker = function(notif)
          return {
            value = notif,
            display = function(entry)
              return displayer({
                { vim.fn.strftime(time_format, entry.value.time), "NotifyLogTime" },
                { entry.value.title[1], "NotifyLogTitle" },
                { entry.value.icon, "Notify" .. entry.value.level .. "Title" },
                { entry.value.level, "Notify" .. entry.value.level .. "Title" },
                { entry.value.message[1], "Notify" .. entry.value.level .. "Body" },
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
          if selection == nil then
            return
          end

          local notification = selection.value
          local opened_buffer = notify.open(notification)

          local lines = vim.opt.lines:get()
          local cols = vim.opt.columns:get()

          local win = vim.api.nvim_open_win(opened_buffer.buffer, true, {
            relative = "editor",
            row = (lines - opened_buffer.height) / 2,
            col = (cols - opened_buffer.width) / 2,
            height = opened_buffer.height,
            width = opened_buffer.width,
            border = "rounded",
            style = "minimal",
          })
          -- vim.wo does not behave like setlocal, thus we use setwinvar to set local
          -- only options. Otherwise our changes would affect subsequently opened
          -- windows.
          -- see e.g. neovim#14595
          vim.fn.setwinvar(
            win,
            "&winhl",
            "Normal:"
              .. opened_buffer.highlights.body
              .. ",FloatBorder:"
              .. opened_buffer.highlights.border
          )
          vim.fn.setwinvar(win, "&wrap", 0)
        end)
        return true
      end,
      previewer = previewers.new_buffer_previewer({
        title = "Message",
        define_preview = function(self, entry, status)
          local notification = entry.value
          local max_width = vim.api.nvim_win_get_config(status.preview_win).width
          notify.open(notification, { buffer = self.state.bufnr, max_width = max_width })
        end,
      }),
    })
    :find()
end

return require("telescope").register_extension({
  exports = {
    notify = telescope_notifications,
  },
})
