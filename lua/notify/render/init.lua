---@tag notify-render
---@text
--- Notification buffer rendering
---
--- Custom rendering can be provided by both the user config in the setup or on
--- an individual notification using the `render` key.
--- The key can either be the name of a built-in renderer or a custom function.
---
--- Built-in renderers:
--- - `"default"`
--- - `"minimal"`
--- - `"simple"`
---
--- Custom functions should accept a buffer, a notification record and a highlights table
---
--- >
---     render: fun(buf: integer, notification: notify.Record, highlights: notify.Highlights, config)
--- <
--- You should use the provided highlight groups to take advantage of opacity
--- changes as they will be updated as the notification is animated

---@class notify.Highlights
---@field title string
---@field icon string
---@field border string
---@field body string

local M = {}

setmetatable(M, {
  __index = function(_, key)
    return require("notify.render." .. key)
  end,
})

return M
