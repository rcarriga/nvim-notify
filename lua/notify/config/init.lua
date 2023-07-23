---@tag notify.config

local Config = {}
local util = require("notify.util")

require("notify.config.highlights")

local BUILTIN_RENDERERS = {
  DEFAULT = "default",
  MINIMAL = "minimal",
}

local BUILTIN_STAGES = {
  FADE = "fade",
  SLIDE = "slide",
  FADE_IN_SLIDE_OUT = "fade_in_slide_out",
  STATIC = "static",
}

local default_config = {
  level = vim.log.levels.INFO,
  timeout = 5000,
  max_width = nil,
  max_height = nil,
  stages = BUILTIN_STAGES.FADE_IN_SLIDE_OUT,
  render = BUILTIN_RENDERERS.DEFAULT,
  background_colour = "NotifyBackground",
  on_open = nil,
  on_close = nil,
  minimum_width = 50,
  fps = 30,
  top_down = true,
  time_formats = {
    notification_history = "%FT%T",
    notification = "%T",
  },
  icons = {
    ERROR = "",
    WARN = "",
    INFO = "",
    DEBUG = "",
    TRACE = "✎",
  },
}

---@class notify.Config
---@field level string|integer Minimum log level to display. See vim.log.levels.
---@field timeout number Default timeout for notification
---@field max_width number|function Max number of columns for messages
---@field max_height number|function Max number of lines for a message
---@field stages string|function[] Animation stages
---@field background_colour string For stages that change opacity this is treated as the highlight behind the window. Set this to either a highlight group, an RGB hex value e.g. "#000000" or a function returning an RGB code for dynamic values
---@field icons table Icons for each level (upper case names)
---@field time_formats table Time formats for different kind of notifications
---@field on_open function Function called when a new window is opened, use for changing win settings/config
---@field on_close function Function called when a window is closed
---@field render function|string Function to render a notification buffer or a built-in renderer name
---@field minimum_width integer Minimum width for notification windows
---@field fps integer Frames per second for animation stages, higher value means smoother animations but more CPU usage
---@field top_down boolean whether or not to position the notifications at the top or not

local opacity_warned = false

local function validate_highlight(colour_or_group, needs_opacity)
  if type(colour_or_group) == "function" then
    return colour_or_group
  end
  if colour_or_group:sub(1, 1) == "#" then
    return function()
      return colour_or_group
    end
  end
  return function()
    local group = vim.api.nvim_get_hl_by_name(colour_or_group, true)
    if not group or not group.background then
      if needs_opacity and not opacity_warned then
        opacity_warned = true
        vim.schedule(function()
          vim.notify("Highlight group '" .. colour_or_group .. [[' has no background highlight
Please provide an RGB hex value or highlight group with a background value for 'background_colour' option.
This is the colour that will be used for 100% transparency.
```lua
require("notify").setup({
  background_colour = "#000000",
})
```
Defaulting to #000000]], "warn", {
            title = "nvim-notify",
            on_open = function(win)
              local buf = vim.api.nvim_win_get_buf(win)
              vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
            end,
          })
        end)
      end
      return "#000000"
    end
    return string.format("#%x", group.background)
  end
end

function Config._format_default()
  local lines = { "Default values:", ">lua" }
  for line in vim.gsplit(vim.inspect(default_config), "\n", true) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "<")
  return lines
end

function Config.setup(custom_config)
  local user_config = vim.tbl_deep_extend("keep", custom_config or {}, default_config)
  local config = {}

  function config.merged()
    return user_config
  end

  function config.level()
    local level = user_config.level
    if type(level) == "number" then
      return level
    end
    return vim.log.levels[vim.fn.toupper(level)] or vim.log.levels.INFO
  end

  function config.fps()
    return user_config.fps
  end

  function config.background_colour()
    return tonumber(user_config.background_colour():gsub("#", "0x"), 16)
  end

  function config.time_formats()
    return user_config.time_formats
  end

  function config.icons()
    return user_config.icons
  end

  function config.stages()
    return user_config.stages
  end

  function config.default_timeout()
    return user_config.timeout
  end

  function config.on_open()
    return user_config.on_open
  end

  function config.top_down()
    return user_config.top_down
  end

  function config.on_close()
    return user_config.on_close
  end

  function config.render()
    return user_config.render
  end

  function config.minimum_width()
    return user_config.minimum_width
  end

  function config.max_width()
    return util.is_callable(user_config.max_width) and user_config.max_width()
      or user_config.max_width
  end

  function config.max_height()
    return util.is_callable(user_config.max_height) and user_config.max_height()
      or user_config.max_height
  end

  local stages = config.stages()

  local needs_opacity =
    vim.tbl_contains({ BUILTIN_STAGES.FADE_IN_SLIDE_OUT, BUILTIN_STAGES.FADE }, stages)

  if needs_opacity and not vim.opt.termguicolors:get() then
    user_config.stages = BUILTIN_STAGES.STATIC
    vim.schedule(function()
      vim.notify(
        "Opacity changes require termguicolors to be set.\nChange to different animation stages or set termguicolors to disable this warning",
        "warn",
        { title = "nvim-notify" }
      )
    end)
  end

  user_config.background_colour = validate_highlight(user_config.background_colour, needs_opacity)

  return config
end

return Config
