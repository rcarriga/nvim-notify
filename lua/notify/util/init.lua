local M = {}

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
  for _, field in pairs({ "row", "col" }) do
    if type(conf[field]) == "table" then
      conf[field] = conf[field][false]
    end
  end
  return success, conf
end

function M.set_win_config(win, conf)
  for _, field in pairs({ "height", "width" }) do
    conf[field] = math.max(M.round(conf[field]), 1)
  end
  return (pcall(vim.api.nvim_win_set_config, win, conf))
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

function M.deep_equal(t1, t2, ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)

  if ty1 ~= ty2 then
    return false
  end
  if ty1 ~= "table" then
    return t1 == t2
  end

  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then
    return t1 == t2
  end

  local checked

  for k1, v1 in pairs(t1) do
    local v2 = t2[k1]
    checked[k1] = true
    if v2 == nil or not M.deep_equal(v1, v2, ignore_mt) then
      return false
    end
  end

  for k2, _ in pairs(t2) do
    if not checked[k2] then
      return false
    end
  end
  return true
end

function M.update_configs(updates)
  for win, win_updates in pairs(updates) do
    local exists, conf = M.get_win_config(win)
    if exists then
      for _, field in pairs({ "row", "col", "height", "width" }) do
        conf[field] = win_updates[field] or conf[field]
      end
      M.set_win_config(win, conf)
    end
  end
end

function M.highlight(name, fields)
  local fields_string = ""
  for field, value in pairs(fields) do
    fields_string = fields_string .. " " .. field .. "=" .. value
  end
  vim.cmd("hi " .. name .. fields_string)
end

return M
