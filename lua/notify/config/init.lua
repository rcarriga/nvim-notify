local M = {}

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
  timeout = 5000,
  stages = BUILTIN_STAGES.FADE_IN_SLIDE_OUT,
  render = BUILTIN_RENDERERS.DEFAULT,
  background_colour = "Normal",
  on_open = nil,
  minimum_width = 50,
  icons = {
    ERROR = "",
    WARN = "",
    INFO = "",
    DEBUG = "",
    TRACE = "✎",
  },
}

local user_config = default_config

local function validate_highlight(colour_or_group, needs_opacity)
  if colour_or_group:sub(1, 1) == "#" then
    return colour_or_group
  end
  local group_bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(colour_or_group)), "bg#")
  if group_bg == "" or group_bg == "none" then
    if needs_opacity then
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

function M.setup(config)
  local filled = vim.tbl_deep_extend("keep", config or {}, default_config)
  user_config = filled
  local stages = M.stages()

  local needs_opacity = vim.tbl_contains(
    { BUILTIN_STAGES.FADE_IN_SLIDE_OUT, BUILTIN_STAGES.FADE },
    stages
  )

  user_config.background_colour = validate_highlight(user_config.background_colour, needs_opacity)
end

---@param colour_or_group string

function M.background_colour()
  return user_config.background_colour
end

function M.icons()
  return user_config.icons
end

function M.stages()
  return user_config.stages
end

function M.default_timeout()
  return user_config.timeout
end

function M.on_open()
  return user_config.on_open
end

function M.render()
  return user_config.render
end

function M.minimum_width()
  return user_config.minimum_width
end

return M
