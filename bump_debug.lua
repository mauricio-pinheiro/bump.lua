
local bump = require 'bump'

local bump_debug = {}

local function getCellRect(world, cx,cy)
  local l,t = world:toWorld(cx,cy)
  return l,t,world.cellSize,world.cellSize
end

function bump_debug.draw(world)
  for cy, row in pairs(world.rows) do
    for cx, cell in pairs(row) do
      local l,t,w,h = getCellRect(world, cx,cy)
      local intensity = cell.itemCount * 20 + 30
      love.graphics.setColor(200,200,200, intensity)
      love.graphics.rectangle('fill', l,t,w,h)
      love.graphics.setColor(200,200,200)
      love.graphics.print(cell.itemCount, l+12, t+12)
      love.graphics.rectangle('line', l,t,w,h)
    end
  end
end

return bump_debug
