local ffi = require 'cffi'

ffi.cdef [[
  typedef struct timeval {
    long tv_sec;
    long tv_usec;
  } timeval;
  int gettimeofday(struct timeval* t, void* tzp);
  int usleep(unsigned int usec);
]]

---Creates a new coroutine scheduler.
local function Scheduler()
  local tasks = {
    ready = {},
    sleeping = {}
  }

  local function current_msec()
    local t = ffi.new('timeval')
    ffi.C.gettimeofday(t, nil)
    return t.tv_sec * 1000 + t.tv_usec / 1000
  end

  local function sleep_msec(msec)
    ffi.C.usleep(msec * 1000)
  end

  local function resume_task(co, ...)
    if coroutine.status(co) == 'suspended' then
      coroutine.resume(co, ...)
    elseif coroutine.status(co) == 'normal' then
      coroutine.yield(co, ...)
    end
  end

  local kernel = coroutine.create(function()
    while true do
      local current_msec = current_msec()

      for _, task in ipairs(tasks.sleeping) do
        if task.wakeup <= current_msec then
          local co = table.remove(tasks.sleeping, 1).co
          table.insert(tasks.ready, { co = co })
        else
          break
        end
      end

      if #tasks.ready > 0 then
        local task = table.remove(tasks.ready, 1)
        resume_task(task.co, table.unpack(task.args or {}))
      elseif #tasks.sleeping > 0 then
        sleep_msec(tasks.sleeping[1].wakeup - current_msec)
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

  ---Returns the current coroutine.
  ---@return thread
  local function current()
    return (coroutine.running())
  end

  ---Creates a new coroutine and adds it to the ready queue.
  ---@param f function
  local function spawn(f)
    local co = coroutine.create(f)
    table.insert(tasks.ready, { co = co })
    return co
  end

  ---Removes a coroutine from the scheduler. It is removed from the ready
  ---queue and will not resume if sleeping.
  ---@param co thread
  local function destroy(co)
    for i, task in ipairs(tasks.ready) do
      if task.co == co then
        table.remove(tasks.ready, i)
        return
      end
    end
    for i, task in ipairs(tasks.sleeping) do
      if task.co == co then
        table.remove(tasks.sleeping, i)
        return
      end
    end
  end

  ---Pauses the current coroutine and allows other coroutines to run. The
  ---coroutine is immediately added to the ready queue.
  local function yield()
    local co = coroutine.running()
    table.insert(tasks.ready, { co = co })
    resume_kernel()
  end

  ---Pauses coroutine for a given number of milliseconds and allows other
  ---coroutines to run.
  ---@param msec number
  local function sleep(msec)
    table.insert(tasks.sleeping, {
      co = coroutine.running(),
      wakeup = current_msec() + msec
    })
    table.sort(tasks.sleeping, function(a, b)
      return a.wakeup < b.wakeup
    end)
    resume_kernel()
  end

  ---Pauses a coroutine and allows other coroutines to run. The coroutine is
  ---only resumed when `resume` is called and returns any arguments passed to
  ---`resume`.
  ---@return any
  local function pause()
    return resume_kernel()
  end

  ---Resumes a coroutine with optional arguments.
  ---@param co thread
  ---@vararg any
  local function resume(co, ...)
    table.insert(tasks.ready, { co = co, args = { ... } })
  end

  return {
    current = current,
    spawn = spawn,
    destroy = destroy,
    yield = yield,
    sleep = sleep,
    pause = pause,
    resume = resume
  }
end

return Scheduler
