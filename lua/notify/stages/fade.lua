local stages_util = require("notify.stages.util")

return {
  function(open_windows, state)
    local next_height = state.height + 2
    local next_row = stages_util.available_row(open_windows, next_height)
    if not next_row then
      return nil
    end
    return {
      relative = "editor",
      anchor = "NE",
      width = state.width,
      height = state.height,
      col = vim.opt.columns:get(),
      row = next_row,
      border = "rounded",
      style = "minimal",
      opacity = 0,
    }
  end,
  function()
    return {
      opacity = { 100 },
      col = { vim.opt.columns:get() },
    }
  end,
  function()
    return {
      col = { vim.opt.columns:get() },
      time = 2000,
    }
  end,
  function()
    return {
      opacity = {
        0,
        frequency = 2,
        complete = function(cur_opacity)
          return cur_opacity <= 4
        end,
      },
      col = { vim.opt.columns:get() },
    }
  end,
}
