local M = {}

function M.is_callable(obj)
  return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

function M.lazy_require(require_path)
  return setmetatable({}, {
    __call = function(_, ...)
      return require(require_path)(...)
    end,
    __index = function(_, key)
      return require(require_path)[key]
    end,
    __newindex = function(_, key, value)
      require(require_path)[key] = value
    end,
  })
end

function M.pop(tbl, key, default)
  local val = default
  if tbl[key] then
    val = tbl[key]
    tbl[key] = nil
  end
  return val
end

function M.crop(val, min, max)
  return math.min(math.max(min, val), max)
end

function M.zip(first, second)
  local new = {}
  for i, val in pairs(first) do
    new[i] = { val, second[i] }
  end
  return new
end

local function split_hex_colour(hex)
  hex = hex:gsub("#", "")
  return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

function M.blend(fg_hex, bg_hex, alpha)
  local channels = M.zip(split_hex_colour(fg_hex), split_hex_colour(bg_hex))

  local blended = {}
  for i, i_chans in pairs(channels) do
    blended[i] = M.round(M.crop(alpha * i_chans[1] + (1 - alpha) * i_chans[2], 0, 255))
  end

  return string.format("#%02x%02x%02x", unpack(blended))
end

function M.round(num, decimals)
  if decimals then
    return tonumber(string.format("%." .. decimals .. "f", num))
  end
  return math.floor(num + 0.5)
end

function M.partial(func, ...)
  local args = { ... }
  return function(...)
    local final = {}
    vim.list_extend(final, args)
    vim.list_extend(final, { ... })
    return func(unpack(final))
  end
end

function M.get_win_config(win)
  local success, conf = pcall(vim.api.nvim_win_get_config, win)
  if not success or not conf.row then
    return false, conf
  end
  if type(conf.row) == "table" then
    conf.row = conf.row[false]
  end
  if type(conf.col) == "table" then
    conf.col = conf.col[false]
  end
  return success, conf
end

function M.open_win(notif_buf, enter, opts)
  local win = vim.api.nvim_open_win(notif_buf:buffer(), enter, opts)
  -- vim.wo does not behave like setlocal, thus we use setwinvar to set local
  -- only options. Otherwise our changes would affect subsequently opened
  -- windows.
  -- see e.g. neovim#14595
  vim.fn.setwinvar(
    win,
    "&winhl",
    "Normal:" .. notif_buf.highlights.body .. ",FloatBorder:" .. notif_buf.highlights.border
  )
  vim.fn.setwinvar(win, "&wrap", 0)
  return win
end

M.FIFOQueue = require("notify.util.queue")

function M.rgb_to_numbers(s)
  local colours = {}
  for a in string.gmatch(s, "[A-Fa-f0-9][A-Fa-f0-9]") do
    colours[#colours + 1] = tonumber(a, 16)
  end
  return colours
end

function M.numbers_to_rgb(colours)
  local colour = "#"
  for _, num in pairs(colours) do
    colour = colour .. string.format("%X", num)
  end
  return colour
end

function M.highlight(name, fields)
  local fields_string = ""
  for field, value in pairs(fields) do
    fields_string = fields_string .. " " .. field .. "=" .. value
  end
  if fields_string ~= "" then
    vim.cmd("hi " .. name .. fields_string)
  end
end

return M
