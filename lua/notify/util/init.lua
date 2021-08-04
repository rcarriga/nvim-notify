local M = {}

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

return M
