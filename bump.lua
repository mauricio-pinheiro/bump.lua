local bump = {
  _VERSION     = 'bump v2.0.0',
  _URL         = 'https://github.com/kikito/bump.lua',
  _DESCRIPTION = 'A collision detection library for Lua',
  _LICENSE     = [[
    MIT LICENSE

    Copyright (c) 2013 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]
}

------------------------------------------
-- Auxiliary functions
------------------------------------------

local abs, floor, ceil, min, max = math.abs, math.floor, math.ceil, math.min, math.max

local function clamp(x, lower, upper)
  return max(lower, min(upper, x))
end

local function sign(x)
  if x > 0 then return 1 end
  if x == 0 then return 0 end
  return -1
end

local function nearest(x, a, b)
  if abs(a - x) < abs(b - x) then return a else return b end
end

local function toDict(arr)
  local dict = {}
  for _,v in pairs(arr) do dict[v] = true end
  return dict
end

local function sortByTi(a,b)    return a.ti < b.ti end
local function sortByWeight(a,b) return a.weight < b.weight end

local function assertType(desiredType, value, name)
  if type(value) ~= desiredType then
    error(name .. ' must be a ' .. desiredType .. ', but was ' .. tostring(value) .. '(a ' .. type(value) .. ')')
  end
end

local function assertIsPositiveNumber(value, name)
  if type(value) ~= 'number' or value <= 0 then
    error(name .. ' must be a positive integer, but was ' .. tostring(value) .. '(' .. type(value) .. ')')
  end
end

local function assertIsBox(l,t,w,h)
  assertType('number', l, 'l')
  assertType('number', t, 'w')
  assertIsPositiveNumber(w, 'w')
  assertIsPositiveNumber(h, 'h')
end

------------------------------------------
-- Axis-aligned bounding box functions
------------------------------------------

local function aabb_getNearestCorner(l,t,w,h, x, y)
  return nearest(x, l, l+w), nearest(y, t, t+h)
end

-- This is a generalized implementation of the liang-barsky algorithm, which also returns
-- the normals of the sides where the segment intersects.
-- Returns nil if the segment never touches the box
-- Notice that normals are only guaranteed to be accurate when initially ti1, ti2 == -math.huge, math.huge
local function aabb_getSegmentIntersectionIndices(l,t,w,h, x1,y1,x2,y2, ti1,ti2)
  ti1, ti2 = ti1 or 0, ti2 or 1
  local dx, dy = x2-x1, y2-y1
  local nx, ny
  local nx1, ny1, nx2, ny2 = 0,0,0,0
  local p, q, r

  for side = 1,4 do
    if     side == 1 then nx,ny,p,q = -1,  0, -dx, x1 - l     -- left
    elseif side == 2 then nx,ny,p,q =  1,  0,  dx, l + w - x1 -- right
    elseif side == 3 then nx,ny,p,q =  0, -1, -dy, y1 - t     -- top
    else                  nx,ny,p,q =  0,  1,  dy, t + h - y1 -- bottom
    end

    if p == 0 then
      if q <= 0 then return nil end
    else
      r = q / p
      if p < 0 then
        if     r > ti2 then return nil
        elseif r > ti1 then ti1,nx1,ny1 = r,nx,ny
        end
      else -- p > 0
        if     r < ti1 then return nil
        elseif r < ti2 then ti2,nx2,ny2 = r,nx,ny
        end
      end
    end
  end

  return ti1,ti2, nx1,ny1, nx2,ny2
end

-- Calculates the minkowsky difference between 2 aabbs, which is another aabb
local function aabb_getDiff(l1,t1,w1,h1, l2,t2,w2,h2)
  return l2 - l1 - w1,
         t2 - t1 - h1,
         w1 + w2,
         h1 + h2
end

local delta = 0.00001 -- floating-point-safe comparisons here, otherwise bugs
local function aabb_containsPoint(l,t,w,h, x,y)
  return x - l > delta     and y - t > delta and
         l + w - x > delta and t + h - y > delta
end

local function aabb_isIntersecting(l1,t1,w1,h1, l2,t2,w2,h2)
  return l1 < l2+w2 and l2 < l1+w1 and
         t1 < t2+h2 and t2 < t1+h1
end

------------------------------------------
-- Collision
------------------------------------------

local Collision = {}
local Collision_mt = {__index = Collision}

function Collision:resolve()
  local b1, b2          = self.itemBox, self.otherBox
  local vx, vy          = self.vx, self.vy
  local l1,t1,w1,h1     = b1.l, b1.t, b1.w, b1.h
  local l2,t2,w2,h2     = b2.l, b2.t, b2.w, b2.h
  local l,t,w,h         = aabb_getDiff(l1,t1,w1,h1, l2,t2,w2,h2)

  if aabb_containsPoint(l,t,w,h, 0,0) then -- b1 was intersecting b2
    self.is_intersection = true
    local px, py = aabb_getNearestCorner(l,t,w,h, 0, 0)
    local wi, hi = min(w1, abs(px)), min(h1, abs(py)) -- area of intersection
    self.ti      = -wi * hi -- ti is the negative area of intersection
    self.nx, self.ny = 0,0
    self.ml, self.mt, self.mw, self.mh = l,t,w,h
    return self
  else
    local ti1,ti2,nx,ny = aabb_getSegmentIntersectionIndices(l,t,w,h, 0,0,vx,vy, -math.huge, math.huge)
    -- b1 tunnels into b2 while it travels
    if ti1 and ti1 < 1 and (0 < ti1 or 0 == ti1 and ti2 > 0) then
      -- local dx, dy = vx*ti-vx, vy*ti-vy
      self.is_intersection = false
      self.ti, self.nx, self.ny          = ti1, nx, ny
      self.ml, self.mt, self.mw, self.mh = l,t,w,h
      return self
    end
  end
end

function Collision:getTouch()
  local vx,vy = self.vx, self.vy
  local itemBox = self.itemBox
  assert(self.is_intersection ~= nil, 'unknown collision kind. Have you called :resolve()?')

  local tl, tt, nx, ny

  if self.is_intersection then

    if vx == 0 and vy == 0 then
      -- intersecting and not moving - use minimum displacement vector
      local px,py = aabb_getNearestCorner(self.ml, self.mt, self.mw, self.mh, 0,0)
      if abs(px) < abs(py) then py = 0 else px = 0 end
      tl, tt, nx, ny = itemBox.l + px, itemBox.t + py, sign(px), sign(py)
    else
      -- intersecting and moving - move in the opposite direction
      local ti,_,nx2,ny2 = aabb_getSegmentIntersectionIndices(self.ml,self.mt,self.mw,self.mh, 0,0,vx,vy, -math.huge, 1)
      tl, tt, nx, ny = itemBox.l + vx * ti, itemBox.t + vy * ti, nx2, ny2
    end

  else -- tunnel
    tl, tt, nx, ny = itemBox.l + vx * self.ti, itemBox.t + vy * self.ti, self.nx, self.ny
  end

  return tl, tt, nx, ny
end

function Collision:getSlide()
  local tl, tt, nx, ny  = self:getTouch()
  local sl, st = tl, tt

  if self.vx ~= 0 or self.vy ~= 0 then
    if nx == 0 then
      sl = self.future_l
    else
      st = self.future_t
    end
  end

  return tl, tt, nx, ny, sl, st
end

function Collision:getBounce()
  local tl, tt, nx, ny  = self:getTouch()
  local bl, bt, bx,by = tl, tt, 0,0

  if self.vx ~= 0 or self.vy ~= 0 then
    bx, by = self.future_l - tl, self.future_t - tt
    if nx == 0 then by = -by else bx = -bx end
    bl, bt = tl + bx, tt + by
  end

  return tl, tt, nx, ny, bl, bt
end

------------------------------------------
-- World
------------------------------------------

local function getBox(self, item)
  local box = self.boxes[item]
  if not box then
    error('Item ' .. tostring(item) .. ' must be added to the world before getting its box. Use world:add(item, l,t,w,h) to add it first.')
  end
  return box
end

local function toCellBox(self, l,t,w,h)
  local cellSize = self.cellSize
  local cl,ct    = self:toCell(l, t)
  local cr,cb    = ceil((l+w) / cellSize), ceil((t+h) / cellSize)
  return cl, ct, cr-cl+1, cb-ct+1
end

local function addItemToCell(self, item, cx, cy)
  self.rows[cy] = self.rows[cy] or setmetatable({}, {__mode = 'v'})
  local row = self.rows[cy]
  row[cx] = row[cx] or {itemCount = 0, x = cx, y = cy, items = setmetatable({}, {__mode = 'k'})}
  local cell = row[cx]
  self.nonEmptyCells[cell] = true
  if not cell.items[item] then
    cell.items[item] = true
    cell.itemCount = cell.itemCount + 1
  end
end

local function removeItemFromCell(self, item, cx, cy)
  local row = self.rows[cy]
  if not row or not row[cx] or not row[cx].items[item] then return false end

  local cell = row[cx]
  cell.items[item] = nil
  cell.itemCount = cell.itemCount - 1
  if cell.itemCount == 0 then
    self.nonEmptyCells[cell] = nil
  end
  return true
end

local function getDictItemsInCellBox(self, cl,ct,cw,ch)
  local items_dict = {}
  for cy=ct,ct+ch-1 do
    local row = self.rows[cy]
    if row then
      for cx=cl,cl+cw-1 do
        local cell = row[cx]
        if cell and cell.itemCount > 0 then -- no cell.itemCount > 1 because tunneling
          for item,_ in pairs(cell.items) do
            items_dict[item] = true
          end
        end
      end
    end
  end

  return items_dict
end

local function getSegmentStep(cellSize, ct, t1, t2)
  local v = t2 - t1
  if     v > 0 then
    return  1,  cellSize / v, ((ct + v) * cellSize - t1) / v
  elseif v < 0 then
    return -1, -cellSize / v, ((ct + v - 1) * cellSize - t1) / v
  else
    return 0, math.huge, math.huge
  end
end

local function getCellsTouchedBySegment(self, x1,y1,x2,y2)

  local cx1,cy1        = self:toCell(x1,y1)
  local cx2,cy2        = self:toCell(x2,y2)
  local stepX, dx, tx  = getSegmentStep(self.cellSize, cx1, x1, x2)
  local stepY, dy, ty  = getSegmentStep(self.cellSize, cy1, y1, y2)
  local maxLen         = 2*(abs(cx2-cx1) + abs(cy2-cy1))
  local cx,cy          = cx1,cy1
  local coords, len = {{cx=cx,cy=cy}}, 1

  -- maxLen is a safety guard. In some cases this algorithm loops inf on the last step without it
  while len <= maxLen and (cx~=cx2 or cy~=cy2) do
    if tx < ty then
      tx, cx, len = tx + dx, cx + stepX, len + 1
      coords[len] = {cx=cx,cy=cy}
    elseif ty < tx then
      ty, cy, len = ty + dy, cy + stepY, len + 1
      coords[len] = {cx=cx,cy=cy}
    else -- tx == ty
      local ntx,nty = tx+dx, dy+dy
      local ncx,ncy = cx+stepX, cy+stepY

      len = len + 1
      coords[len] = {cx=ncx,cy=cy}
      len = len + 1
      coords[len] = {cx=cx,cy=ncy}

      tx,ty = ntx,nty
      cx,cy = ncx,ncy
    end
  end

  local coord, row, cell
  local visited = {}
  local cells, cellsLen = {}, 0
  for i=1,len do
    coord = coords[i]
    row   = self.rows[coord.cy]
    if row then
      cell = row[coord.cx]
      if cell then
        if not visited[cell] then
          visited[cell] = true
          cellsLen = cellsLen + 1
          cells[cellsLen] = cell
        end
      end
    end
  end

  return cells, cellsLen
end

local function getInfoAboutItemsTouchedBySegment(self, x1,y1, x2,y2)
  local cells, len = getCellsTouchedBySegment(self, x1,y1,x2,y2)
  local cell, box, l,t,w,h, ti1,ti2, tii0,tii1
  local visited, itemInfo, itemInfoLen = {},{},0
  for i=1,len do
    cell = cells[i]
    for item in pairs(cell.items) do
      if not visited[item] then
        visited[item]  = true
        box            = self.boxes[item]
        l,t,w,h        = box.l,box.t,box.w,box.h

        ti1,ti2 = aabb_getSegmentIntersectionIndices(l,t,w,h, x1,y1, x2,y2, 0, 1)
        if ti1 and ((0 < ti1 and ti1 < 1) or (0 < ti2 and ti2 < 1)) then
          -- the sorting is according to the t of an infinite line, not the segment
          tii0,tii1      = aabb_getSegmentIntersectionIndices(l,t,w,h, x1,y1, x2,y2, -math.huge, math.huge)
          itemInfoLen  = itemInfoLen + 1
          itemInfo[itemInfoLen] = {item = item, ti1 = ti1, ti2 = ti2, weight = min(tii0,tii1)}
        end
      end
    end
  end
  table.sort(itemInfo, sortByWeight)
  return itemInfo, itemInfoLen
end

local World = {}
local World_mt = {__index = World}

function World:add(item, l,t,w,h)
  local box = self.boxes[item]
  if box then
    error('Item ' .. tostring(item) .. ' added to the world twice.')
  end
  assertIsBox(l,t,w,h)

  self.boxes[item] = {l=l,t=t,w=w,h=h}

  local cl,ct,cw,ch = toCellBox(self, l,t,w,h)
  for cy = ct, ct+ch-1 do
    for cx = cl, cl+cw-1 do
      addItemToCell(self, item, cx, cy)
    end
  end
end

function World:remove(item)
  local box = getBox(self, item)

  self.boxes[item] = nil
  local cl,ct,cw,ch = toCellBox(self, box.l,box.t,box.w,box.h)
  for cy = ct, ct+ch-1 do
    for cx = cl, cl+cw-1 do
      removeItemFromCell(self, item, cx, cy)
    end
  end
end

function World:move(item, l,t, ignore, filter)
  local box             = getBox(self, item)
  local collisions, len = self:check(item, l, t, ignore, filter)

  if box.l ~= l or box.t ~= t then
    self:teleport(item, l, t, box.w, box.h)
  end

  return collisions, len
end

function World:teleport(item, l,t,w,h)
  self:remove(item)
  self:add(item, l,t,w,h)
end

function World:check(item, future_l, future_t, ignore, filter)
  local box = getBox(self, item)
  local collisions, len = {}, 0

  ignore       = toDict(ignore or {})
  ignore[item] = true

  local l,t,w,h = box.l, box.t, box.w, box.h
  future_l, future_t = future_l or l, future_t or t

  -- TODO this could probably be done with less cells using a polygon raster over the cells instead of a
  -- bounding box of the whole movement. Conditional to building a queryPolygon method
  local tl, tt = min(future_l, l),       min(future_t, t)
  local tr, tb = max(future_l + w, l+w), max(future_t + h, t+h)
  local tw, th = tr-tl, tb-tt

  local cl,ct,cw,ch = toCellBox(self, tl,tt,tw,th)

  local dictItemsInCellBox = getDictItemsInCellBox(self, cl,ct,cw,ch)

  for other,_ in pairs(dictItemsInCellBox) do
    if not ignore[other] then
      ignore[other] = true
      if not (filter and filter(other)) then
        local oBox = self.boxes[other]
        local col  = bump.newCollision(item, other, box, oBox, future_l, future_t):resolve()
        if col then
          len = len + 1
          collisions[len] = col
        end
      end
    end
  end

  table.sort(collisions, sortByTi)

  return collisions, len
end

function World:getBox(item)
  local box = getBox(self, item)
  return box.l, box.t, box.w, box.h
end

function World:countCells()
  local count = 0
  for _,row in pairs(self.rows) do
    for _,_ in pairs(row) do
      count = count + 1
    end
  end
  return count
end

function World:toWorld(cx, cy)
  local cellSize = self.cellSize
  return (cx - 1)*cellSize, (cy-1)*cellSize
end

function World:toCell(x,y)
  local cellSize = self.cellSize
  return floor(x / cellSize) + 1, floor(y / cellSize) + 1
end

function World:queryBox(l,t,w,h)

  local cl,ct,cw,ch = toCellBox(self, l,t,w,h)
  local dictItemsInCellBox = getDictItemsInCellBox(self, cl,ct,cw,ch)

  local items, len = {}, 0

  local box
  for item,_ in pairs(dictItemsInCellBox) do
    box = self.boxes[item]
    if aabb_isIntersecting(l,t,w,h, box.l, box.t, box.w, box.h) then
      len = len + 1
      items[len] = item
    end
  end

  return items, len
end

function World:queryPoint(x,y)
  local cx,cy = self:toCell(x,y)
  local dictItemsInCellBox = getDictItemsInCellBox(self, cx,cy,1,1)

  local items, len = {}, 0

  local box
  for item,_ in pairs(dictItemsInCellBox) do
    box = self.boxes[item]
    if aabb_containsPoint(box.l, box.t, box.w, box.h, x, y) then
      len = len + 1
      items[len] = item
    end
  end

  return items, len
end

function World:querySegment(x1, y1, x2, y2)
  local itemInfo, len = getInfoAboutItemsTouchedBySegment(self, x1, y1, x2, y2)
  local items = {}
  for i=1, len do
    items[i] = itemInfo[i].item
  end
  return items, len
end

function World:querySegmentWithCoords(x1, y1, x2, y2)
  local itemInfo, len = getInfoAboutItemsTouchedBySegment(self, x1, y1, x2, y2)
  local dx, dy        = x2-x1, y2-y1
  local info, ti1, ti2
  for i=1, len do
    info  = itemInfo[i]
    ti1   = info.ti1
    ti2   = info.ti2

    info.weight  = nil
    info.x1      = x1 + dx * ti1
    info.y1      = y1 + dy * ti1
    info.x2      = x1 + dx * ti2
    info.y2      = y1 + dy * ti2
  end
  return itemInfo, len
end

bump.newWorld = function(cellSize)
  cellSize = cellSize or 64
  assertIsPositiveNumber(cellSize, 'cellSize')
  return setmetatable(
    { cellSize       = cellSize,
      boxes          = {},
      rows           = {},
      nonEmptyCells  = {}
    },
    World_mt
  )
end

bump.newCollision = function(item, other, itemBox, otherBox, future_l, future_t)
  return setmetatable({
    item      = item,
    other     = other,
    itemBox   = itemBox,
    otherBox  = otherBox,
    future_l  = future_l,
    future_t  = future_t,
    vx        = future_l - itemBox.l,
    vy        = future_t - itemBox.t
  }, Collision_mt)
end

return bump
