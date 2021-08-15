local M = {}

M.groups = {'border', 'title'}

-- Example of levels:
-- {
--   [0] = {  -- An integer, alternative to 'name'
--     name = "trace",  -- minimal required field
--     icon = "✎",
--     border = {fg = "#7A1F1F"},  -- border highlight group
--     title = {fg = "#CC0000"}  -- title hightligth group
--   }
-- }
function M.setup(levels, default)
  -- If 'default' is set, we set the lighlight as overwritable
  default = default or false

  -- Example of an expected command:
  -- "hi default NotifyTRACETitle guifg=#D484FF"
  for level, config in pairs(levels) do
    for _, group in pairs(M.groups) do
      -- The command starts by 'hi default? Notify' ..
      local hlcommand = "hi " .. (default and "default" or "") .. " Notify"

      -- Then the level, to upper (ERROR, TRACE, ...)
      hlcommand = hlcommand .. string.upper(config.name)

      -- Then we add the group, capitalized (Border, Title)
      hlcommand = hlcommand .. (group:gsub("^%l", string.upper))

      -- Then we add 'guibg=..', 'guifg=..' if they're given
      for key, val in pairs(config[group]) do
          hlcommand = string.format("%s gui%s=%s", hlcommand, key, val)
      end
      vim.cmd(hlcommand)
    end
  end
end

return M
