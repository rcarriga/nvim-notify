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
  level = "info",
  timeout = 5000,
  max_width = nil,
  max_height = nil,
  stages = BUILTIN_STAGES.FADE_IN_SLIDE_OUT,
  render = BUILTIN_RENDERERS.DEFAULT,
  background_colour = "Normal",
  on_open = nil,
  on_close = nil,
  minimum_width = 50,
  fps = 30,
  icons = {
    ERROR = "",
    WARN = "",
    INFO = "",
    DEBUG = "",
    TRACE = "✎",
  },
}

---@class notify.Config
---@field level string: Minimum log level to display.
---@field timeout number: Default timeout for notification
---@field max_width number | function: Max number of columns for messages
---@field max_height number | function: Max number of lines for a message
---@field stages string | function[]: Animation stages
---@field background_colour string: For stages that change opacity this is treated as the highlight behind the window. Set this to either a highlight group, an RGB hex value e.g. "#000000" or a function returning an RGB code for dynamic values
---@field icons table: Icons for each level (upper case names)
---@field on_open function: Function called when a new window is opened, use for changing win settings/config
---@field on_close function: Function called when a window is closed
---@field render function | string: Function to render a notification buffer or a built-in renderer name
---@field minimum_width integer: Minimum width for notification windows
---@field fps integer: Frames per second for animation stages, higher value means smoother animations but more CPU usage

local user_config = default_config

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
    local group_bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(colour_or_group)), "bg#")
    if group_bg == "" or group_bg == "none" then
      if needs_opacity and not opacity_warned then
        opacity_warned = true
        vim.schedule(function()
          vim.notify(
            "Highlight group '"
              .. colour_or_group
              .. "' has no background highlight.\n\n"
              .. "Please provide an RGB hex value or highlight group with a background value for 'background_colour' option\n\n"
              .. "Defaulting to #000000",
            "warn",
            { title = "nvim-notify" }
          )
        end)
      end
      return "#000000"
    end
    return group_bg
  end
end

function Config.setup(config)
  local filled = vim.tbl_deep_extend("keep", config or {}, default_config)
  user_config = filled
  local stages = Config.stages()

  local needs_opacity = vim.tbl_contains(
    { BUILTIN_STAGES.FADE_IN_SLIDE_OUT, BUILTIN_STAGES.FADE },
    stages
  )

  if needs_opacity and not vim.opt.termguicolors:get() then
    filled.stages = BUILTIN_STAGES.STATIC
    vim.schedule(function()
      vim.notify(
        "Opacity changes require termguicolors to be set.\nChange to different animation stages or set termguicolors to disable this warning",
        "warn",
        { title = "nvim-notify" }
      )
    end)
  end

  user_config.background_colour = validate_highlight(user_config.background_colour, needs_opacity)
end

function Config._format_default()
  local lines = { "<pre>", "Default values:" }
  for line in vim.gsplit(vim.inspect(default_config), "\n", true) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "</pre>")
  return lines
end

---@param colour_or_group string

function Config.level()
  local level = user_config.level
  if type(level) == "number" then
    level = vim.lsp.log_levels[level] or vim.lsp.log_levels.INFO
  end
  return vim.lsp.log_levels[vim.fn.toupper(level)] or vim.lsp.log_levels.INFO
end

function Config.fps()
  return user_config.fps
end

function Config.background_colour()
  return tonumber(user_config.background_colour():gsub("#", "0x"), 16)
end

function Config.icons()
  return user_config.icons
end

function Config.stages()
  return user_config.stages
end

function Config.default_timeout()
  return user_config.timeout
end

function Config.on_open()
  return user_config.on_open
end

function Config.on_close()
  return user_config.on_close
end

function Config.render()
  return user_config.render
end

function Config.minimum_width()
  return user_config.minimum_width
end

function Config.max_width()
  return util.is_callable(user_config.max_width) and user_config.max_width()
    or user_config.max_width
end

function Config.max_height()
  return util.is_callable(user_config.max_height) and user_config.max_height()
    or user_config.max_height
end

return Config
