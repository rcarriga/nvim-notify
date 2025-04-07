local util = require("notify.util")

---@class NotifyBufHighlights
---@field groups table
---@field opacity number
---@field title string
---@field border string
---@field icon string
---@field body string
---@field buffer number
---@field _config table
local NotifyBufHighlights = {}

function NotifyBufHighlights:new(level, buffer, config)
  local function linked_group(section)
    local orig = "Notify" .. level .. section
    if vim.fn.hlID(orig) == 0 then
      orig = "NotifyINFO" .. section
    end
    local new = orig .. buffer

    vim.api.nvim_set_hl(0, new, { link = orig })
    local hl = vim.api.nvim_get_hl(0, { name = orig, create = false, link = false })
    -- Removes the unwanted 'default' key, as we will copy the table for updating the highlight later.
    hl.default = nil

    return new, hl
  end

  local title, title_def = linked_group("Title")
  local border, border_def = linked_group("Border")
  local body, body_def = linked_group("Body")
  local icon, icon_def = linked_group("Icon")

  local groups = {
    [title] = title_def,
    [border] = border_def,
    [body] = body_def,
    [icon] = icon_def,
  }
  local buf_highlights = {
    groups = groups,
    opacity = 100,
    border = border,
    body = body,
    title = title,
    icon = icon,
    buffer = buffer,
    _config = config,
  }
  self.__index = self
  setmetatable(buf_highlights, self)
  return buf_highlights
end

function NotifyBufHighlights:_redefine_treesitter()
  local buf_highlighter = require("vim.treesitter.highlighter").active[self.buffer]

  if not buf_highlighter then
    return
  end
  local render_namespace = vim.api.nvim_create_namespace("notify-treesitter-override")
  vim.api.nvim_buf_clear_namespace(self.buffer, render_namespace, 0, -1)

  local function link(orig)
    local new = orig .. self.buffer
    if self.groups[new] then
      return new
    end
    vim.api.nvim_set_hl(0, new, { link = orig })
    self.groups[new] = vim.api.nvim_get_hl(0, { name = new, link = false })
    return new
  end

  local matches = {}

  local i = 0
  buf_highlighter.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root = tstree:root()

    local query = buf_highlighter:get_query(tree:lang())

    -- Some injected languages may not have highlight queries.
    if not query:query() then
      return
    end

    local iter = query:query():iter_captures(root, buf_highlighter.bufnr)

    for capture, node, metadata in iter do
      -- Wait until we get at least a single capture as we don't know when parsing is complete.
      self._treesitter_redefined = true
      local hl = query.hl_cache[capture]

      if hl then
        i = i + 1
        local c = query._query.captures[capture] -- name of the capture in the query
        if c ~= nil then
          local capture_hl
          -- Removed in nightly with change of highlight names to @...
          -- https://github.com/neovim/neovim/pull/19931
          if query._get_hl_from_capture then
            local general_hl, is_vim_hl = query:_get_hl_from_capture(capture)
            capture_hl = is_vim_hl and general_hl or (tree:lang() .. general_hl)
          else
            capture_hl = query._query.captures[capture]
            if not vim.startswith(capture_hl, "_") then
              capture_hl = "@" .. capture_hl .. "." .. tree:lang()
            end
          end

          local start_row, start_col, end_row, end_col = node:range()
          local custom_hl = link(capture_hl)

          vim.api.nvim_buf_set_extmark(self.buffer, render_namespace, start_row, start_col, {
            end_row = end_row,
            end_col = end_col,
            hl_group = custom_hl,
            -- TODO: Not sure how neovim's highlighter doesn't have issues with overriding highlights
            -- Three marks on same region always show the second for some reason AFAICT
            priority = tonumber(metadata.priority) or i + 200,
            conceal = metadata.conceal,
          })
        end
      end
    end
  end, true)
  return matches
end

function NotifyBufHighlights:set_opacity(alpha)
  if
    not self._treesitter_redefined
    and vim.api.nvim_get_option_value("filetype", { buf = self.buffer }) ~= "notify"
  then
    self:_redefine_treesitter()
  end
  self.opacity = alpha
  local background = self._config.background_colour()
  local updated = false
  for group, fields in pairs(self.groups) do
    local fg = fields.fg
    if fg then
      fg = util.blend(fg, background, alpha / 100)
    end
    local bg = fields.bg
    if bg then
      bg = util.blend(bg, background, alpha / 100)
    end

    if fg ~= fields.fg or bg ~= fields.bg then
      local hl = vim.tbl_extend("force", fields, { fg = fg, bg = bg })
      vim.api.nvim_set_hl(0, group, hl)
      updated = true
    end
  end
  return updated
end

function NotifyBufHighlights:get_opacity()
  return self.opacity
end

---@return NotifyBufHighlights
return function(level, buffer, config)
  return NotifyBufHighlights:new(level, buffer, config)
end
