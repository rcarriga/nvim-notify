---@brief [[
---A fancy, configurable notification manager for NeoVim
---@brief ]]

---@tag nvim-notify

local util = require("notify.util")

local config = require("notify.config")
local stages = require("notify.stages")
local Notification = require("notify.service.notification")
local WindowAnimator = require("notify.windows")
local NotificationService = require("notify.service")

local service
---@type Notification[]
local notifications = {}

local notify = {}

---Configure nvim-notify with custom settings
---@param user_config table: Custom config
---@field timeout number: Default timeout for notification
---@field stages function[]: Animation stages
---@field background_colour string: For stages that change opacity this is treated as the highlight behind the window. Set this to either a highlight group or an RGB hex value e.g. "#000000"
---@field icons table<string, string>: Icons for each level (upper case names)
---@field on_open function | nil: Function called when a new window is opened, use for changing win settings/config
---@field on_close function | nil: Function called when a window is closed
---@field render function | string: Function to render a notification buffer or a built-in renderer name
---@field minimum_width integer: Minimum width for notification windows
---@see notify-render
function notify.setup(user_config)
  config.setup(user_config)

  local has_telescope = (vim.fn.exists("g:loaded_telescope") == 1)
  if has_telescope then
    require("telescope").load_extension("notify")
  end

  local animator_stages = config.stages()
  animator_stages = type(animator_stages) == "string" and stages[animator_stages] or animator_stages
  local animator = WindowAnimator(animator_stages)
  service = NotificationService(function(...)
    return animator:render(...)
  end)

  vim.cmd([[command! Notifications :lua require("notify")._print_history()<CR>]])
end

local function get_render(render)
  if type(render) == "function" then
    return render
  end
  return require("notify.render")[render]
end

---@class NotifyOptions @Options for an individual notification
---@field title string | nil
---@field icon string | nil
---@field timeout number | nil: Time to show notification in milliseconds.
---@field on_open function | nil: Callback for when window opens, receives window as argument.
---@field on_close function | nil: Callback for when window closes, receives window as argument.
---@field keep function | nil: Function to keep the notification window open after timeout, should return boolean.
---@field render function: Function to render a notification buffer.

---@class NotificationEvents @Async events for a notification
---@field open function: Resolves when notification is opened
---@field close function: Resolved when notification is closed

---@class NotificationRecord @Record of a previously sent notification
---@field message string[]: Lines of the message
---@field level string: Log level
---@field title string[]: Left and right sections of the title
---@field icon string: Icon used for notification
---@field time number: Time of message, as returned by `vim.fn.localtime()`
---@field render function: Function to render notification buffer

---Display a notification.
---
---You can call the module directly rather than using this:
---<pre>
--->
---  require("notify")(message, level, opts)
---</pre>
---@param message string | string[]: Notification message
---@param level string | number | nil
---@param opts NotifyOptions | nil: Notification options
function notify.notify(message, level, opts)
  if not service then
    notify.setup()
  end
  opts = opts or {}
  opts.render = get_render(opts.render or config.render())
  local notification = Notification(message, level, opts)
  table.insert(notifications, notification)
  service:push(notification)
end

---Display a notification asynchronously
---
---This uses plenary's async library, allowing a cleaner interface for
---open/close events. You must call this function within an async context.
---
---The `on_close` and `on_open` options are not used.
---
---@param message string | string[]: Notification message
---@param level string | number | nil
---@param opts NotifyOptions | nil: Notification options
---@return NotificationEvents
function notify.async(message, level, opts)
  opts = opts or {}
  local async = require("plenary.async")
  async.util.scheduler()
  local close_cond = async.control.Condvar.new()
  local close_args = {}
  opts.on_close = function(...)
    close_args = { ... }
    close_cond:notify_all()
  end

  local open_cond = async.control.Condvar.new()
  local open_args = {}
  opts.on_open = function(...)
    open_args = { ... }
    open_cond:notify_all()
  end

  notify.notify(message, level, opts)
  return {
    open = function()
      open_cond:wait()
      return unpack(open_args)
    end,
    close = function()
      close_cond:wait()
      return unpack(close_args)
    end,
  }
end

---Get records of all previous notifications
---
--- You can use the `:Notifications` command to display a log of previous notifications
---@return NotificationRecord[]
function notify.history()
  return vim.tbl_map(function(notif)
    return notif:record()
  end, notifications)
end

---Dismiss all notification windows currently displayed
---@param opts table
---@field pending boolean: Clear pending notifications
function notify.dismiss(opts)
  if service then
    service:dismiss(opts or {})
  end
end

function notify._print_history()
  for _, notif in ipairs(notify.history()) do
    vim.api.nvim_echo({
      { vim.fn.strftime("%FT%T", notif.time), "NotifyLogTime" },
      { " ", "MsgArea" },
      { notif.title[1], "NotifyLogTitle" },
      { #notif.title[1] > 0 and " " or "", "MsgArea" },
      { notif.icon, "Notify" .. notif.level .. "Title" },
      { #notif.title[1] > 0 and " " or "", "MsgArea" },
      { notif.level, "Notify" .. notif.level .. "Title" },
      { " ", "MsgArea" },
      { table.concat(notif.message, "\n"), "MsgArea" },
    }, false, {})
  end
end

setmetatable(notify, {
  __call = function(_, m, l, o)
    if vim.in_fast_event() then
      vim.schedule(function()
        notify.notify(m, l, o)
      end)
    else
      notify.notify(m, l, o)
    end
  end,
})

return notify
