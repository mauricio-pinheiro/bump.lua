local bump = require 'bump'

describe('World', function()

  describe(':add', function()
    it('requires something + 4 numbers', function()
      local world = bump.newWorld()
      assert.error(function() world:add({}) end)
      assert.error(function() world:add({}, 40) end)
      assert.error(function() world:add() end)
    end)

    describe('when the world is empty', function()
      it('returns an empty list of collisions', function()
        local world = bump.newWorld()
        assert.same(world:add({}, 0,0,10,10), {})
      end)
    end)

    describe('when the world is not empty', function()
      it('returns an empty list of collisions', function()
        local world, a, b = bump.newWorld(), {}, {}

        world:add(a, 0,0,10,10)
        local cols = world:add(b, 4,6,10,10)

        assert.same(cols, {
          { item = a, dx = 6, dy = 4, tunneling = false, ti = 0 }
        })

      end)
    end)
  end)

  describe(':move', function()

    describe('when the object is not there', function()
      it('throws an error', function()
        local world = bump.newWorld()
        assert.is_error(function() world:move({}, 0,0,10,10) end)
      end)
    end)

    describe('when the world is empty', function()
      it('returns an empty list of collisions', function()
        local world = bump.newWorld()
        assert.same(world:add({}, 0,0,10,10), {})
      end)
    end)

    describe('when the world is not empty', function()
      it('returns a list of collisions', function()
        local world, a, b = bump.newWorld(), {}, {}

        world:add(a, 0,0,10,10)
        assert.same(world:add(b, 4,6,10,10), {
          { item = a, dx = 6, dy = 4, tunneling = false, ti = 0 }
        })

      end)
    end)
  end)

  describe(':check', function()
    describe('when the item does not exist', function()
      it('throws an error', function()
        local world = bump.newWorld()
        assert.error(function() world:check({}) end)
      end)
    end)
    describe('when the world is empty', function()
      it('returns an empty list of collisions', function()
        local world = bump.newWorld()
        local obj = {}
        world:add(obj, 1,2,3,4)
        assert.same(world:check(obj), {})
      end)
    end)

    describe('when the world is not empty', function()
      it('returns a list of collisions', function()
        local world, a, b = bump.newWorld(), {}, {}

        world:add(a, 0,0,10,10)
        world:add(b, 4,6,10,10)
        assert.same(world:check(b), {
          { item = a, dx = 6, dy = 4, tunneling = false, ti = 0 }
        })

      end)

      describe('when a displacement vector is passed', function()
        it('still handles intersections as before', function()
          local world, a, b = bump.newWorld(), {}, {}

          world:add(a, 0,0, 2,2)
          world:add(b, 1,1, 2,2)
          assert.same(world:check(b, 1,1), {
            { item = a, dx = 1, dy = 1, tunneling = false, ti = 0 }
          })
        end)
        it('detects and tags tunneling correctly', function()
          local world, a, b = bump.newWorld(), {}, {}

          world:add(a, 1,0, 2,1)
          world:add(b, 5,0, 4,1)
          assert.same(world:check(b, 10, 0), {
            { item = a, dx = -8, dy = 0, tunneling = true, ti = 0.2 }
          })
        end)

        it('returns a list of collisions sorted by ti', function()
          local world, a, b, c, d = bump.newWorld(), {'a'}, {'b'}, {'c'}, {'d'}

          world:add(a, 1,0, 1,1)
          world:add(b, 7,0, 1,1)
          world:add(c, 5,0, 1,1)
          world:add(d, 9,0, 1,1)
          assert.same(world:check(a, -10, 0), {
            { item = d, dx = 9, dy = 0, tunneling = true, ti = 0.1 },
            { item = b, dx = 7, dy = 0, tunneling = true, ti = 0.3 },
            { item = c, dx = 5, dy = 0, tunneling = true, ti = 0.5 }
          })
        end)
      end)
    end)
  end)
end)
