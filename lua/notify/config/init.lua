local M = {}

local highlight = require("notify.config.highlights")

-- Configuration section
local default_config = {
  -- Default level and default icon (must exist, name or integer)
  default_level = "info",

  -- Definition of each level (type of notification)
  levels = {
    -- Note: the default list matches vim.lsp.log_levels

    [0] = {  -- An integer, alternative to 'name'
      name = "trace",  -- minimal required field
      icon = "✎",
      border = {fg = "#848482"},  -- border highlight group
      title = {fg = "#797979"}  -- title hightligth group
    },
    [1] = {
      name = "debug",
      icon = "",
      border = {fg = "#008B8B"},
      title = {fg = "#008B8B"}
    },
    [2] = {
      name = "info",
      icon = "",
      border = {fg = "#6699CC"},
      title = {fg = "#6699CC"}
    },
    [3] = {
      name = "warn",
      icon = "",
      border = {fg = "#B6A642"},
      title = {fg = "#B5A642"}
    },
    [4] = {
      name = "error",
      icon = "",
      border = {fg = "#7A1F1F"},
      title = {fg = "#CC0000"}
    }
  }
}
-- Set the default highlights
highlight.setup(default_config.levels, true)


local function validate_level(level, level_config)
  -- Validate top level keys
  vim.validate({
    level={level, 'number'},
    name={level_config.name, 'string'},
    icon={level_config.icon, 'string', true},
    border={level_config.border, 'table', true},
    title={level_config.title, 'table', true}
  })

  -- Validate the highlight groups
  for _, hgroup in pairs(highlight.groups) do
    local group = level_config[hgroup]
    if group ~= nil then
      -- So far we only support fg & bg
      vim.validate({
          fg={group.fg, 'string', true},
          bg={group.fg, 'string', true},
      })
    end
  end
end

-- Start with user_config as default. Built it when config.setup() is called
local user_config = default_config

function M.setup(config)
  -- tbl extend does not work properly with integers maps (see neovim/#15382)
  local filled = vim.tbl_deep_extend("keep", config or {}, user_config)
  -- it does work when the integer keys are n=on the main level though
  filled.levels = vim.tbl_deep_extend("keep", config.levels or {}, user_config.levels)
  --print(vim.inspect(filled))

  -- Check the consistency of the new user config
  for level, level_config in pairs(filled.levels) do
    validate_level(level, level_config)
    -- We want to set the default as a number for faster access
    if level == filled.default_level or
        level_config.name == filled.default_level then
        filled.default_level_number = level
    end
  end

  -- Revert the change if the default is invalid
  if filled.default_level_number == nil then
    print("Provided default ("..filled.default_level..") is invalid")
    return
  end

  -- Set the changes if everything seems alright
  user_config = filled

  -- Set highlights
  highlight.setup(user_config.levels, false)
  require("dapui.config.highlights").setup()
end

function M.default_level()
  -- If we're not using the defaults, default_level_number exists
  return user_config.default_level_number or 2
end

function M.levels()
  return user_config.levels
end

return M
