-- Adapted from https://gist.github.com/Fraktality/1033625223e13c01aa7144abe4aaf54d
-- Explanation found here https://www.ryanjuckett.com/damped-springs/
local pi = math.pi
local exp = math.exp
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt

---@class SpringState
---@field position number
---@field velocity number | nil

---@param dt number @Step in time
---@param state SpringState
return function(dt, goal, state, frequency, damping)
  local angular_freq = frequency * 2 * pi

  local cur_vel = state.velocity or 0

  local offset = state.position - goal
  local decay = exp(-dt * damping * angular_freq)

  local new_pos
  local new_vel

  if damping == 1 then -- critically damped
    new_pos = (cur_vel * dt + offset * (angular_freq * dt + 1)) * decay + goal
    new_vel = (cur_vel - angular_freq * dt * (offset * angular_freq + cur_vel)) * decay
  elseif damping < 1 then -- underdamped
    local c = sqrt(1 - damping * damping)

    local i = cos(angular_freq * c * dt)
    local j = sin(angular_freq * c * dt)

    new_pos = (i * offset + j * (cur_vel + damping * angular_freq * offset) / (angular_freq * c))
        * decay
      + goal
    new_vel = (i * c * cur_vel - j * (cur_vel * damping + angular_freq * offset)) * decay / c
  else -- overdamped
    local c = sqrt(damping * damping - 1)

    local r1 = -angular_freq * (damping - c)
    local r2 = -angular_freq * (damping + c)

    local co2 = (cur_vel - r1 * offset) / (2 * angular_freq * c)
    local co1 = offset - co2

    local e1 = co1 * exp(r1 * dt)
    local e2 = co2 * exp(r2 * dt)

    new_pos = e1 + e2 + goal
    new_pos = r1 * e1 + r2 * e2
  end
  state.position = new_pos
  state.velocity = new_vel
end
