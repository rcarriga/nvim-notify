---@class FIFOQueue
local FIFOQueue = {}

function FIFOQueue:pop()
  if self:is_empty() then
    return nil
  end
  local r = self[self.pop_from]
  self[self.pop_from] = nil
  self.pop_from = self.pop_from - 1
  return r
end

function FIFOQueue:peek()
  return self[self.pop_from]
end

function FIFOQueue:push(val)
  self[self.push_to] = val
  self.push_to = self.push_to - 1
end

function FIFOQueue:is_empty()
  return self:length() == 0
end

function FIFOQueue:length()
  return self.pop_from - self.push_to
end

function FIFOQueue:iter()
  local i = self.pop_from + 1
  return function()
    if i > self.push_to + 1 then
      i = i - 1
      return self[i]
    end
  end
end

function FIFOQueue:new()
  local queue = {
    pop_from = 1,
    push_to = 1,
  }
  self.__index = self
  setmetatable(queue, self)
  return queue
end

---@return FIFOQueue
return function()
  return FIFOQueue:new()
end
