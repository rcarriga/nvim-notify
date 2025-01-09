local notify = require("notify")
local time_format = notify._config().time_formats().notification

local builtin = require("fzf-lua.previewer.builtin")
local fzf = require("fzf-lua")

local M = {}

---@alias NotifyMessage {id: number, message: notify.Record, texts: string[][]}
---@alias NotifyEntry {ordinal: string, display: string}

---@param message NotifyMessage
---@return NotifyEntry
function M.entry(message)
  local display = message.id .. " " ---@type string
  local content = ""
  for _, text in ipairs(message.texts) do
    ---@type string?
    local hl_group = text[2]
    display = display .. (hl_group and fzf.utils.ansi_from_hl(hl_group, text[1]) or text[1])
    content = content .. text[1]
  end

  return {
    message = message.message,
    ordinal = content,
    display = display,
  }
end

function M.find()
  local messages = notify.history()

  ---@type table<number, NotifyEntry>
  local ret = {}

  for _, message in ipairs(messages) do
    ret[message.id] = M.entry({
      id = message.id,
      message = message,
      texts = {
        { vim.fn.strftime(time_format, message.time) .. " ", "NotifyLogTime" },
        { message.title[1] .. " ", "NotifyLogTitle" },
        { message.icon .. " ", "Notify" .. message.level .. "Title" },
        { message.level .. " ", "Notify" .. message.level .. "Title" },
        { message.message[1], "Notify" .. message.level .. "Body" },
      },
    })
  end

  return ret
end

function M.parse_entry(messages, entry_str)
  local id = tonumber(entry_str:match("^%d+"))
  local entry = messages[id]
  return entry
end

---@param messages table<number, NotifyEntry>
function M.previewer(messages)
  local previewer = builtin.buffer_or_file:extend()

  function previewer:new(o, opts, fzf_win)
    previewer.super.new(self, o, opts, fzf_win)
    self.title = "Message"
    setmetatable(self, previewer)
    return self
  end

  function previewer:populate_preview_buf(entry_str)
    local buf = self:get_tmp_buffer()
    local entry = M.parse_entry(messages, entry_str)

    if entry then
      local notification = entry.message
      notify.open(notification, { buffer = buf, max_width = 0 })
    end

    self:set_preview_buf(buf)
    self.win:update_preview_title(" Message ")
    self.win:update_preview_scrollbar()
    self.win:set_winopts(self.win.preview_winid, { wrap = true })
  end

  return previewer
end

---@param opts? table<string, any>
function M.open(opts)
  local messages = M.find()
  opts = vim.tbl_deep_extend("force", opts or {}, {
    prompt = false,
    winopts = {
      title = " Filter Notifications ",
      title_pos = "center",
      preview = {
        title = " Message ",
        title_pos = "center",
      },
    },
    previewer = M.previewer(messages),
    fzf_opts = {
      ["--no-multi"] = "",
      ["--with-nth"] = "2..",
    },
    actions = {
      default = function(selected)
        if #selected == 0 then
          return
        end
        local notification = M.parse_entry(messages, selected[1]).message

        local opened_buffer = notify.open(notification)

        local lines = vim.opt.lines:get()
        local cols = vim.opt.columns:get()

        local win = vim.api.nvim_open_win(opened_buffer.buffer, true, {
          relative = "editor",
          row = (lines - opened_buffer.height) / 2,
          col = (cols - opened_buffer.width) / 2,
          height = opened_buffer.height,
          width = opened_buffer.width,
          border = "rounded",
          style = "minimal",
        })
        -- vim.wo does not behave like setlocal, thus we use setwinvar to set local
        -- only options. Otherwise our changes would affect subsequently opened
        -- windows.
        -- see e.g. neovim#14595
        vim.fn.setwinvar(
          win,
          "&winhl",
          "Normal:"
            .. opened_buffer.highlights.body
            .. ",FloatBorder:"
            .. opened_buffer.highlights.border
        )
        vim.fn.setwinvar(win, "&wrap", 0)
      end,
    },
  })
  local lines = vim.tbl_map(function(entry)
    return entry.display
  end, vim.tbl_values(messages))
  return fzf.fzf_exec(lines, opts)
end

return M
