local config = require("notify.config")
local util = require("notify.util")

---@class NotifyBufHighlights
---@field groups table
---@field opacity number
---@field title string
---@field border string
---@field icon string
---@field body string
local NotifyBufHighlights = {}

local function group_fields(group)
  return {
    guifg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), "fg"),
    guibg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), "bg"),
  }
end

function NotifyBufHighlights:new(level, buffer)
  local function linked_group(section)
    local orig = "Notify" .. level .. section
    if vim.fn.hlID(orig) == 0 then
      orig = "NotifyINFO" .. section
    end
    local new = orig .. buffer
    vim.cmd("silent! hi link " .. new .. " " .. orig)
    return new
  end
  local title = linked_group("Title")
  local border = linked_group("Border")
  local body = linked_group("Body")
  local icon = linked_group("Icon")

  local groups = {}
  for _, group in pairs({ title, border, body, icon }) do
    groups[group] = group_fields(group)
  end
  local buf_highlights = {
    groups = groups,
    opacity = 100,
    border = border,
    body = body,
    title = title,
    icon = icon,
  }
  self.__index = self
  setmetatable(buf_highlights, self)
  return buf_highlights
end

function NotifyBufHighlights:set_opacity(alpha)
  self.opacity = alpha
  local background = config.background_colour()
  for group, fields in pairs(self.groups) do
    local updated_fields = {}
    for name, value in pairs(fields) do
      if value ~= "" and value ~= "none" then
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
