local scheduler = require 'Scheduler'()

scheduler.spawn(function()
  print('1.1')
  scheduler.sleep(100)
  print('1.2')
end, 'task 1')

scheduler.spawn(function()
  print('2.1')
  scheduler.sleep(50)
  print('2.2')
end, 'task 2')

local pause = scheduler.spawn(function()
  print(scheduler.pause())
end, 'task pause')

local infinite = scheduler.spawn(function()
  while true do
    print('∞')
    scheduler.sleep(100)
  end
end, 'task infinite')

print('0.1')
scheduler.sleep(500)
print('0.2')

scheduler.resume(pause, 'unpaused')
scheduler.yield()

scheduler.destroy(infinite)
