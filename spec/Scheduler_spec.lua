local Scheduler = require 'Scheduler'
local mach = require 'mach'

describe('Scheduler', function()
  local f1 = mach.mock_function('f1')
  local f2 = mach.mock_function('f2')

  local function nothing_should_happen()
    return mach.mock_function().may_be_called()
  end

  it('should allow the main coroutine to yield', function()
    local scheduler = Scheduler()
    scheduler.yield()
  end)

  it('should run ready coroutines in FIFO order', function()
    local scheduler = Scheduler()

    scheduler.spawn(function()
      f1()
    end)

    scheduler.spawn(function()
      f2()
    end)

    f1.should_be_called()
      .and_then(f2.should_be_called())
      .when(function()
        scheduler.yield()
      end)
  end)

  it('should resume yielded coroutines', function()
    local scheduler = Scheduler()

    scheduler.spawn(function()
      f1()
      scheduler.yield()
      f2()
    end)

    f1.should_be_called()
      .when(function()
        scheduler.yield()
      end)

    f2.should_be_called()
      .when(function()
        scheduler.yield()
      end)
  end)

  it('should allow a coroutine to be paused and resumed', function()
    local scheduler = Scheduler()

    local co = scheduler.spawn(function()
      scheduler.pause()
      f1()
    end)

    nothing_should_happen()
      .when(function()
        scheduler.yield()
      end)

    f1.should_be_called()
      .when(function()
        scheduler.resume(co)
        scheduler.yield()
      end)
  end)

  it('should allow a coroutine to be paused and resumed with arguments', function()
    local scheduler = Scheduler()

    local co = scheduler.spawn(function()
      f1(scheduler.pause())
    end)

    f1.should_be_called_with(1, 2, 3)
      .when(function()
        scheduler.resume(co, 1, 2, 3)
        scheduler.yield()
      end)
  end)

  it('should run a resumed coroutine after other ready coroutines', function()
    local scheduler = Scheduler()

    local co = scheduler.spawn(function()
      scheduler.pause()
      f1()
    end)

    scheduler.spawn(function()
      f2()
    end)

    scheduler.resume(co)

    f2.should_be_called()
      .and_then(f1.should_be_called())
      .when(function()
        scheduler.yield()
      end)
  end)

  it('should allow the main coroutine to sleep', function()
    local scheduler = Scheduler()
    scheduler.sleep(10)
  end)

  it('should allow coroutines to sleep', function()
    local scheduler = Scheduler()

    scheduler.spawn(function()
      f1()
      scheduler.yield()
      f2()
    end)

    f1.should_be_called()
      .and_then(f2.should_be_called())
      .when(function()
        scheduler.sleep(50)
      end)
  end)

  it('should resume sleeping coroutines in the order that they wake', function()
    local scheduler = Scheduler()

    scheduler.spawn(function()
      scheduler.sleep(2)
      f1()
    end)

    scheduler.spawn(function()
      scheduler.sleep(1)
      f2()
    end)

    f2.should_be_called()
      .and_then(f1.should_be_called())
      .when(function()
        scheduler.sleep(10)
      end)
  end)

  it('should allow a spawned coroutine to be destroyed', function()
    local scheduler = Scheduler()
    local destroyed_successfully = true

    local co = scheduler.spawn(function()
      destroyed_successfully = false
    end)
    scheduler.destroy(co)

    scheduler.yield()
    assert.is_true(destroyed_successfully)
  end)

  it('should allow a sleeping coroutine to be destroyed', function()
    local scheduler = Scheduler()
    local destroyed_successfully = true

    local co = scheduler.spawn(function()
      scheduler.sleep(10)
      destroyed_successfully = false
    end)

    scheduler.yield()
    scheduler.destroy(co)
    scheduler.sleep(11)
    assert.is_true(destroyed_successfully)
  end)
end)
