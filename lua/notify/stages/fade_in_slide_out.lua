local stages_util = require("notify.stages.util")

return {
  function(state)
    local next_height = state.message.height + 2
    local next_row = stages_util.available_slot(
      state.open_windows,
      next_height,
      stages_util.DIRECTION.TOP_DOWN
    )
    if not next_row then
      return nil
    end
    return {
      relative = "editor",
      anchor = "NW",
      width = state.message.width,
      height = state.message.height,
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
      time = true,
    }
  end,
  function()
    return {
      width = {
        1,
        frequency = 2.5,
        damping = 0.9,
        complete = function(cur_width)
          return cur_width < 3
        end,
      },
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
