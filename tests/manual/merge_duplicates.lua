local function coroutine_resume()
  local co = assert(coroutine.running())
  return function(...)
    local ret = { coroutine.resume(co, ...) }
    -- Re-raise errors with correct traceback
    local ok, err = unpack(ret)
    if not ok then
      error(debug.traceback(co, err))
    end
    return unpack(ret, 2)
  end
end

local function coroutine_sleep()
  local resume = coroutine_resume()
  return function(ms)
    vim.defer_fn(resume, ms)
    coroutine.yield()
  end
end

local function run()
  local sleep = coroutine_sleep()

  local countdown = function(seconds)
    local id
    for i = 1, seconds do
      -- local msg = string.format('Will show once again in %d seconds', seconds - i + 1)
      local msg = string.format("Will show once again in %d seconds", seconds - i + 1)
      id = vim.notify(msg, vim.log.levels.WARN, { replace = id }).id
      sleep(1000)
    end
  end

  local texts = {
    "AAA This is first text",
    "BBBBBB Second text of duplicate notifications",
    -- 'CCCCCCCCC Third text',
  }

  local show_all = function(level)
    for _, text in ipairs(texts) do
      vim.notify(text, level)
      sleep(50)
    end
  end

  show_all()

  sleep(1000)
  show_all()

  sleep(1000)
  show_all()

  sleep(1000)
  show_all(vim.log.levels.WARN)
  sleep(1000)
  show_all(vim.log.levels.WARN)

  sleep(1000)
  show_all()

  -- wait until the previous notifications disappear
  countdown(10)
  show_all()

  sleep(2000)
  for _ = 1, 41 do
    sleep(50)
    show_all()
  end
end

coroutine.wrap(run)()
