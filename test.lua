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

local infinite = scheduler.spawn(function()
  while true do
    print('∞')
    scheduler.sleep(100)
  end
end, 'infinite')

print('0.1')
scheduler.sleep(500)
print('0.2')

scheduler.destroy(infinite)
