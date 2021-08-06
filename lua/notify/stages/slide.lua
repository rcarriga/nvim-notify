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
      width = 1,
      height = state.height,
      col = vim.opt.columns:get(),
      row = next_row,
      border = "rounded",
      style = "minimal",
    }
  end,
  function(_, state)
    return {
      width = { state.width, frequency = 2 },
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
      width = {
        1,
        frequency = 2.5,
        damping = 0.9,
        complete = function(cur_width)
          return cur_width < 2
        end,
      },
      col = { vim.opt.columns:get() },
    }
  end,
}
