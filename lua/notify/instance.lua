local stages = require("notify.stages")
local config = require("notify.config")
local Notification = require("notify.service.notification")
local WindowAnimator = require("notify.windows")
local NotificationService = require("notify.service")
local NotificationBuf = require("notify.service.buffer")
local stage_util = require("notify.stages.util")

local notif_cmp_keys = {
  "level",
  "message",
  "title",
  "icon",
}

---@param n1 notify.Notification
---@param n2 notify.Notification
---@return boolean
local function notifications_equal(n1, n2)
  for _, key in ipairs(notif_cmp_keys) do
    local v1 = n1[key]
    local v2 = n2[key]
    -- NOTE: Notification:new adds time string which causes not-equality, so compare only left title (1st element)
    if key == "title" then
      v1 = v1[1]
      v2 = v2[1]
    end
    if not vim.deep_equal(v1, v2) then
      return false
    end
  end
  return true
end

---@param user_config notify.Config
---@param inherit? boolean Inherit the global configuration, default true
---@param global_config notify.Config
return function(user_config, inherit, global_config)
  ---@type notify.Notification[]
  local notifications = {}

  user_config = user_config or {}
  if inherit ~= false and global_config then
    user_config = vim.tbl_deep_extend("force", global_config, user_config)
  end

  local instance_config = config.setup(user_config)

  local animator_stages = instance_config.stages()
  local direction = instance_config.top_down() and stage_util.DIRECTION.TOP_DOWN
    or stage_util.DIRECTION.BOTTOM_UP

  animator_stages = type(animator_stages) == "string" and stages[animator_stages](direction)
    or animator_stages
  local animator = WindowAnimator(animator_stages, instance_config)
  local service = NotificationService(instance_config, animator)

  local instance = {}

  local function get_render(render)
    if type(render) == "function" then
      return render
    end
    return require("notify.render")[render]
  end

  ---@param notif notify.Notification
  ---@return notify.Notification?
  local function find_duplicate(notif)
    for _, buf in pairs(animator.notif_bufs) do
      if notifications_equal(buf._notif, notif) then
        return buf._notif
      end
    end
  end

  function instance.notify(message, level, opts)
    opts = opts or {}

    if opts.replace then
      if type(opts.replace) == "table" then
        opts.replace = opts.replace.id
      end
      local existing = notifications[opts.replace]
      if not existing then
        vim.notify("Invalid notification to replace", "error", { title = "nvim-notify" })
        return
      end
      local notif_keys = {
        "title",
        "icon",
        "timeout",
        "keep",
        "on_open",
        "on_close",
        "render",
        "hide_from_history",
        "animate",
      }
      message = message or existing.message
      level = level or existing.level
      for _, key in ipairs(notif_keys) do
        if opts[key] == nil then
          opts[key] = existing[key]
        end
      end
    end

    opts.render = get_render(opts.render or instance_config.render())
    local id = #notifications + 1
    local notification = Notification(id, message, level, opts, instance_config)
    table.insert(notifications, notification)
    local level_num = vim.log.levels[notification.level]

    if not opts.replace and instance_config.merge_duplicates() then
      local dup = find_duplicate(notification)
      if dup then
        dup.duplicates = dup.duplicates or { dup.id }
        table.insert(dup.duplicates, notification.id)
        notification.duplicates = dup.duplicates

        local min_dups = instance_config.merge_duplicates()
        if min_dups == true or #notification.duplicates >= min_dups + 1 then
          opts.replace = dup.id
        end
      end
    end

    if opts.replace then
      service:replace(opts.replace, notification)
    elseif not level_num or level_num >= instance_config.level() then
      service:push(notification)
    end
    return {
      id = id,
    }
  end

  ---@param notif_id integer|notify.Record
  ---@param opts table
  function instance.open(notif_id, opts)
    opts = opts or {}
    if type(notif_id) == "table" then
      notif_id = notif_id.id
    end
    local notif = notifications[notif_id]
    if not notif then
      vim.notify(
        "Invalid notification id: " .. notif_id,
        vim.log.levels.WARN,
        { title = "nvim-notify" }
      )
      return
    end
    local buf = opts.buffer or vim.api.nvim_create_buf(false, true)
    local notif_buf =
      NotificationBuf(buf, notif, vim.tbl_extend("keep", opts, { config = instance_config }))
    notif_buf:render()
    return {
      buffer = buf,
      height = notif_buf:height(),
      width = notif_buf:width(),
      highlights = {
        body = notif_buf.highlights.body,
        border = notif_buf.highlights.border,
        title = notif_buf.highlights.title,
        icon = notif_buf.highlights.icon,
      },
    }
  end

  function instance.async(message, level, opts)
    opts = opts or {}
    local async = require("plenary.async")
    local send_close, wait_close = async.control.channel.oneshot()
    opts.on_close = send_close

    local send_open, wait_open = async.control.channel.oneshot()
    opts.on_open = send_open

    async.util.scheduler()
    local record = instance.notify(message, level, opts)
    return vim.tbl_extend("error", record, {
      events = {
        open = wait_open,
        close = wait_close,
      },
    })
  end

  function instance.history(args)
    args = args or {}
    local records = {}
    for _, notif in ipairs(notifications) do
      if not notif.hide_from_history or args.include_hidden then
        records[#records + 1] = notif:record()
      end
    end
    return records
  end

  function instance.dismiss(opts)
    if service then
      service:dismiss(opts or {})
    end
  end

  function instance.pending()
    return service and service:pending() or {}
  end

  function instance.clear_history()
    notifications = {}
  end

  setmetatable(instance, {
    __call = function(_, m, l, o)
      if vim.in_fast_event() then
        vim.schedule(function()
          instance.notify(m, l, o)
        end)
      else
        return instance.notify(m, l, o)
      end
    end,
  })
  return instance, instance_config.merged()
end
