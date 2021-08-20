local config = require("notify.config")
local util = require("notify.util")

---@class NotifyBufHighlights
---@field groups table
---@field opacity number
---@field title string
---@field border string
---@field body string
local NotifyBufHighlights = {}

local function group_fields(group)
  return {
    guifg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), "fg"),
    guibg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), "bg"),
  }
end

function NotifyBufHighlights:new(level, buffer)
  local orig_title = "Notify" .. level .. "Title"
  local orig_border = "Notify" .. level
  local orig_body = "Notify" .. level .. "Body"
  local title = "Notify" .. level .. "Title" .. buffer
  local border = "Notify" .. level .. buffer
  local body = "Notify" .. level .. "Body" .. buffer
  vim.cmd("hi link " .. title .. " " .. orig_title)
  vim.cmd("hi link " .. border .. " " .. orig_border)
  vim.cmd("hi link " .. body .. " " .. orig_body)

  local groups = {}
  for _, group in pairs({ title, border, body }) do
    groups[group] = group_fields(group)
  end
  local buf_highlights = {
    groups = groups,
    opacity = 100,
    border = border,
    body = body,
    title = title,
  }
  self.__index = self
  setmetatable(buf_highlights, self)
  return buf_highlights
end

function NotifyBufHighlights:set_opacity(alpha)
  self.opacity = alpha
  local background = config.background_highlight()
  for group, fields in pairs(self.groups) do
    local updated_fields = {}
    for name, value in pairs(fields) do
      if value ~= "" then
        updated_fields[name] = util.blend(value, background, alpha / 100)
      end
    end
    util.highlight(group, updated_fields)
  end
end

function NotifyBufHighlights:get_opacity()
  return self.opacity
end

---@return NotifyBufHighlights
return function(level, buffer)
  return NotifyBufHighlights:new(level, buffer)
end
