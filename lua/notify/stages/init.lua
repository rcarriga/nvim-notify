local M = {}

---@class MessageState
---@field width number
---@field height number

---@alias InitStage fun(open_windows: number[], message_state: MessageState): table | nil
---@alias AnimationStage fun(win: number, message_state: MessageState): table

---@alias Stage InitStage | AnimationStage
---@alias Stages Stage[]

setmetatable(M, {
  ---@return Stages
  __index = function(_, key)
    return require("notify.stages." .. key)
  end,
})

return M
