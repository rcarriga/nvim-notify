---@text
--- A fancy, configurable notification manager for NeoVim

local config = require("notify.config")
local instance = require("notify.instance")

---@class notify
local notify = {}

local global_instance, global_config

--- Configure nvim-notify
---    See: ~
---        |notify.Config|
---        |notify-render|
---
---@param user_config notify.Config|nil
---@eval return require('notify.config')._format_default()
function notify.setup(user_config)
  global_instance, global_config = notify.instance(user_config)
  local has_telescope = (vim.fn.exists("g:loaded_telescope") == 1)
  if has_telescope then
    require("telescope").load_extension("notify")
  end
  vim.cmd([[command! Notifications :lua require("notify")._print_history()<CR>]])
end

function notify._config()
  return config.setup(global_config)
end

---@class notify.Options
--- Options for an individual notification
---@field title string
---@field icon string
---@field timeout number|boolean Time to show notification in milliseconds, set to false to disable timeout.
---@field on_open function Callback for when window opens, receives window as argument.
---@field on_close function Callback for when window closes, receives window as argument.
---@field keep function Function to keep the notification window open after timeout, should return boolean.
---@field render function|string Function to render a notification buffer.
---@field replace integer|notify.Record Notification record or the record `id` field. Replace an existing notification if still open. All arguments not given are inherited from the replaced notification including message and level.
---@field hide_from_history boolean Hide this notification from the history
---@field animate boolean If false, the window will jump to the timed stage. Intended for use in blocking events (e.g. vim.fn.input)

---@class notify.Events
--- Async events for a notification
---@field open function Resolves when notification is opened
---@field close function Resolved when notification is closed

---@class notify.Record
--- Record of a previously sent notification
---@field id integer
---@field message string[] Lines of the message
---@field level string|integer Log level. See vim.log.levels
---@field title string[] Left and right sections of the title
---@field icon string Icon used for notification
---@field time number Time of message, as returned by `vim.fn.localtime()`
---@field render function Function to render notification buffer

---@class notify.AsyncRecord : notify.Record
---@field events notify.Events

--- Display a notification.
---
--- You can call the module directly rather than using this:
--- >lua
---  require("notify")(message, level, opts)
--- <
---@param message string|string[] Notification message
---@param level string|number Log level. See vim.log.levels
---@param opts notify.Options Notification options
---@return notify.Record
function notify.notify(message, level, opts)
  if not global_instance then
    notify.setup()
  end
  return global_instance.notify(message, level, opts)
end

--- Display a notification asynchronously
---
--- This uses plenary's async library, allowing a cleaner interface for
--- open/close events. You must call this function within an async context.
---
--- The `on_close` and `on_open` options are not used.
---
---@param message string|string[] Notification message
---@param level string|number Log level. See vim.log.levels
---@param opts notify.Options Notification options
---@return notify.AsyncRecord
function notify.async(message, level, opts)
  if not global_instance then
    notify.setup()
  end
  return global_instance.async(message, level, opts)
end

--- Get records of all previous notifications
---
--- You can use the `:Notifications` command to display a log of previous notifications
---@param opts notify.HistoryOpts
---@return notify.Record[]
function notify.history(opts)
  if not global_instance then
    notify.setup()
  end
  return global_instance.history(opts)
end

---@class notify.HistoryOpts
---@field include_hidden boolean Include notifications hidden from history

--- Dismiss all notification windows currently displayed
---@param opts notify.DismissOpts
function notify.dismiss(opts)
  if not global_instance then
    notify.setup()
  end
  return global_instance.dismiss(opts)
end

---@class notify.DismissOpts
---@field pending boolean Clear pending notifications
---@field silent boolean Suppress notification that pending notifications were dismissed.

--- Open a notification in a new buffer
---@param notif_id integer|notify.Record
---@param opts notify.OpenOpts
---@return notify.OpenedBuffer
function notify.open(notif_id, opts)
  if not global_instance then
    notify.setup()
  end
  return global_instance.open(notif_id, opts)
end

---@class notify.OpenOpts
---@field buffer integer Use this buffer, instead of creating a new one
---@field max_width integer Render message to this width (used to limit window decoration sizes)

---@class notify.OpenedBuffer
---@field buffer integer Created buffer number
---@field height integer Height of the buffer content including extmarks
---@field width integer width of the buffer content including extmarks
---@field highlights table<string, string> Highlights used for the buffer contents

--- Number of notifications currently waiting to be displayed
---@return integer[]
function notify.pending()
  if not global_instance then
    notify.setup()
  end
  return global_instance.pending()
end

function notify._print_history()
  if not global_instance then
    notify.setup()
  end
  for _, notif in ipairs(global_instance.history()) do
    vim.api.nvim_echo({
      {
        vim.fn.strftime(notify._config().time_formats().notification_history, notif.time),
        "NotifyLogTime",
      },
      { " ", "MsgArea" },
      { notif.title[1], "NotifyLogTitle" },
      { #notif.title[1] > 0 and " " or "", "MsgArea" },
      { notif.icon, "Notify" .. notif.level .. "Title" },
      { " ", "MsgArea" },
      { notif.level, "Notify" .. notif.level .. "Title" },
      { " ", "MsgArea" },
      { table.concat(notif.message, "\n"), "MsgArea" },
    }, false, {})
  end
end

--- Configure an instance of nvim-notify.
--- You can use this to manage a separate instance of nvim-notify with completely different configuration.
--- The returned instance will have the same functions as the notify module.
---@param user_config notify.Config
---@param inherit? boolean Inherit the global configuration, default true
function notify.instance(user_config, inherit)
  return instance(user_config, inherit, global_config)
end

setmetatable(notify, {
  __call = function(_, m, l, o)
    if vim.in_fast_event() or vim.fn.has("vim_starting") == 1 then
      vim.schedule(function()
        notify.notify(m, l, o)
      end)
    else
      return notify.notify(m, l, o)
    end
  end,
})

return notify
