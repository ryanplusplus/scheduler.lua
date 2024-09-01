# scheduler.lua
Simple Lua coroutine scheduler. Schedules managed coroutines in FIFO order, allows coroutines to sleep, and allows a coroutine to be paused and resumed with optional arguments (this allows, for example, you to implement non-blocking opertions that sleep the caller and resume when a result is ready).

## Creating a Coroutine
```lua
local scheduler = require 'Scheduler'()

scheduler.spawn(function()
  print('Hello, World!')
end)

scheduler.yield()

--> 'Hello, World!'
```

## Destroying a Coroutine
```lua
local scheduler = require 'Scheduler'()

local co = scheduler.spawn(function()
  print('Hello, World!')
end)
scheduler.destroy(co)

scheduler.yield()
```

## Pausing/Resuming a Coroutine
```lua
local scheduler = require 'Scheduler'()

local co = scheduler.spawn(function()
  print(scheduler.pause())
end)

scheduler.resume(co, 'Hello, World!')

scheduler.yield()

--> 'Hello, World!'
```

## Sleeping a Coroutine
```lua
local scheduler = require 'Scheduler'()

scheduler.spawn(function()
  print('Hello, World!')
  scheduler.sleep(100)
  print('Goodbye, World!')
end)

scheduler.sleep(200)

--> 'Hello, World!'
--> 'Goodbye, World!'
```
