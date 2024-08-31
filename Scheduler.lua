local ffi = require 'cffi'

ffi.cdef [[
  typedef struct timeval {
    long tv_sec;
    long tv_usec;
  } timeval;
  int gettimeofday(struct timeval* t, void* tzp);
  int usleep(unsigned int usec);
]]

-- local debug = true

local debug_print do
  if debug == true then
    debug_print = print
  else
    debug_print = function(...) end
  end
end

local function Scheduler()
  local tasks = {
    ready = {},
    sleeping = {}
  }

  local names = setmetatable({}, {
    __index = function()
      return 'main'
    end
  })

  local function print_ready_tasks()
    for _, task in ipairs(tasks.ready) do
      debug_print('- ' .. names[tostring(task)])
    end
  end

  local function current_msec()
    local t = ffi.new('timeval')
    ffi.C.gettimeofday(t, nil)
    return t.tv_sec * 1000 + t.tv_usec / 1000
  end

  local function sleep_msec(msec)
    ffi.C.usleep(msec * 1000)
  end

  local function resume_task(co, ...)
    debug_print(names[tostring(co)] .. ' status: ' .. coroutine.status(co))
    if coroutine.status(co) == 'suspended' then
      debug_print(names[tostring(co)] .. ' resuming')
      print_ready_tasks()
      coroutine.resume(co, ...)
    elseif coroutine.status(co) == 'normal' then
      debug_print(names[tostring(co)] .. ' resuming')
      print_ready_tasks()
      coroutine.yield(co, ...)
    end
  end

  local kernel = coroutine.create(function()
    while true do
      debug_print('runnign kernel')
      local _current_msec

      if #tasks.sleeping > 0 then
        _current_msec = current_msec()
        if tasks.sleeping[1].wakeup <= _current_msec then
          local co = table.remove(tasks.sleeping, 1).co
          table.insert(tasks.ready, co)
          debug_print(names[tostring(co)] .. ' woke up')
          print_ready_tasks()
        end
      end

      if #tasks.ready > 0 then
        local co = table.remove(tasks.ready, 1)
        resume_task(co)
      elseif #tasks.sleeping > 0 then
        debug_print('no tasks ready, sleeping for ' .. tasks.sleeping[1].wakeup - _current_msec .. ' msec')
        sleep_msec(tasks.sleeping[1].wakeup - _current_msec)
      else
        break
      end
    end
  end)

  local function resume_kernel()
    if coroutine.status(kernel) == 'suspended' then
      return coroutine.resume(kernel)
    else
      return coroutine.yield()
    end
  end

  ---@param f function
  ---@param name string
  local function spawn(f, name)
    local co = coroutine.create(f)
    names[tostring(co)] = name or tostring(co)
    table.insert(tasks.ready, co)
    debug_print(names[tostring(co)] .. ' spawned')
    print_ready_tasks()
    return co
  end

  ---@param co thread
  local function destroy(co)
    for i, task in ipairs(tasks.ready) do
      if task == co then
        debug_print(names[tostring(co)] .. ' destroyed')
        table.remove(tasks.ready, i)
        return
      end
    end
    for i, task in ipairs(tasks.sleeping) do
      debug_print(names[tostring(co)] .. ' destroyed')
      if task.co == co then
        table.remove(tasks.sleeping, i)
        return
      end
    end
  end

  local function yield()
    local co = coroutine.running()
    table.insert(tasks.ready, co)
    debug_print(names[tostring(co)] .. ' yielded')
    print_ready_tasks()
    resume_kernel()
  end

  ---@param msec number
  local function sleep(msec)
    debug_print(names[tostring((coroutine.running()))] .. ' sleeping for ' .. msec .. ' msec')
    table.insert(tasks.sleeping, {
      co = coroutine.running(),
      wakeup = current_msec() + msec
    })
    table.sort(tasks.sleeping, function(a, b)
      return a.wakeup < b.wakeup
    end)
    resume_kernel()
  end

  local function pause()
    local co = coroutine.running()
    debug_print(names[tostring(co)] .. ' paused')
    return resume_kernel()
  end

  ---@param co thread
  ---@vararg any
  local function resume(co, ...)
    debug_print(names[tostring(co)] .. ' resumed')
    -- maybe this should just go into the ready queue with its args
    resume_task(co, ...)
  end

  return {
    spawn = spawn,
    destroy = destroy,
    yield = yield,
    sleep = sleep,
    pause = pause,
    resume = resume
  }
end

return Scheduler
