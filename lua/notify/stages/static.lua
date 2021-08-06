local stage_util = require("notify.stages.util")

return {
  function(open_windows, state)
    local next_height = state.height + 2
    local next_row = stage_util.available_row(open_windows, next_height)
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
    }
  end,
  function()
    return {
      col = { vim.opt.columns:get() },
      time = 2000,
    }
  end,
}
