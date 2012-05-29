require 'lib.middleclass'
local bump   = require 'lib.bump'

local Entity = require 'entities.Entity'
local Block  = require 'entities.Block'
local Player = require 'entities.Player'

local p                    -- the player instance
local maxdt = 0.1          -- max dt; used to clamp max speed

function bump.collision(obj1, obj2, dx, dy)
  if instanceOf(Player, obj2) then
    obj1,obj2,dx,dy = obj2,obj1,-dx,-dy
  end
  obj1:blockCollision(obj2, dx, dy)
end

function bump.endCollision(obj1, obj2)
  if instanceOf(Player, obj2) then
    obj1,obj2 = obj2,obj1
  end
  obj1:endBlockCollision(obj2)
end

function bump.getBBox(obj)
  return obj.l, obj.t, obj.w, obj.h
end

function love.load()
  Block:new(  0,   0, 800,  32)
  Block:new(  0, 568, 800,  32)
  Block:new(  0,  32,  32, 536)
  Block:new(768,  32,  32, 536)

  Block:new(368, 536,  32,  32)

  Player:new(100, 100, 32, 32)
end

function love.update(dt)
  Entity:updateAll(dt, maxdt)
  bump.check()
end

function love.draw()
  Entity:drawAll()
end

function love.keypressed(k)
  if k=="escape" then love.event.quit() end
end
