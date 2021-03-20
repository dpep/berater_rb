module Berater
  class StaticLimiter < Limiter

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
      local key = KEYS[1]
      local capacity = tonumber(ARGV[1])
      local cost = tonumber(ARGV[2])

      local count = redis.call('GET', key) or 0
      local allowed = (count + cost) <= capacity

      if allowed then
        count = count + cost
        redis.call('SET', key, count)
      end

      return { tostring(count), allowed }
    LUA
    )

    protected def acquire_lock(capacity, cost)
      if cost == 0
        # utilization check
        count = redis.get(cache_key) || "0"
        allowed = true
      else
        count, allowed = LUA_SCRIPT.eval(
          redis, [ cache_key ], [ capacity, cost ],
        )
      end

      # Redis returns Floats as strings to maintain precision
      count = count.include?('.') ? count.to_f : count.to_i

      raise Overloaded unless allowed

      release_fn = if cost > 0
        proc { redis.incrbyfloat(cache_key, -cost) }
      end

      Lock.new(capacity, count, release_fn)
    end

    def to_s
      "#<#{self.class}(#{key}: #{capacity})>"
    end

  end
end
