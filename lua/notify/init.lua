local util = require("notify.util")

local config = util.lazy_require("notify.config")
local stages = util.lazy_require("notify.stages")
---@type fun(stages: function[]): WindowAnimator
local WindowAnimator = util.lazy_require("notify.windows")
---@type fun(receiver: fun(pending: FIFOQueue, time: number): table | nil): NotificationService
local NotificationService = util.lazy_require("notify.service")

local service

local function setup(user_config)
  config.setup(user_config)
  local animator_stages = config.stages()
  animator_stages = type(animator_stages) == "string" and stages[animator_stages] or animator_stages
  local animator = WindowAnimator(animator_stages)
  service = NotificationService(function(...)
    return animator:render(...)
  end)
end

---@param message string | string[]
---@param level string | number
---@param opts NotifyOptions
local function notify(_, message, level, opts)
  vim.schedule(function()
    if not service then
      setup()
    end
    service:push(message, level, opts)
  end)
end

local M = { setup = setup }

setmetatable(M, { __call = notify })

return M
