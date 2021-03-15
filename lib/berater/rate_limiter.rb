module Berater
  class RateLimiter < Limiter

    class Overrated < Overloaded; end

    attr_accessor :interval

    def initialize(key, capacity, interval, **opts)
      self.interval = interval
      super(key, capacity, @interval_msec, **opts)
    end

    private def interval=(interval)
      @interval = interval
      @interval_msec = Berater::Utils.to_msec(interval)

      unless @interval_msec > 0
        raise ArgumentError, 'interval must be > 0'
      end
    end

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
      local key = KEYS[1]
      local ts_key = KEYS[2]
      local ts = tonumber(ARGV[1])
      local capacity = tonumber(ARGV[2])
      local interval_msec = tonumber(ARGV[3])
      local cost = tonumber(ARGV[4])

      local allowed -- whether lock was acquired
      local count -- capacity being utilized
      local msec_per_drip = interval_msec / capacity
      local state = redis.call('GET', key)

      if state then
        local last_ts -- timestamp of last update
        count, last_ts = string.match(state, '([%d.]+);(%w+)')
        count = tonumber(count)
        last_ts = tonumber(last_ts, 16)

        -- adjust for time passing, guarding against clock skew
        if ts > last_ts then
          local drips = math.floor((ts - last_ts) / msec_per_drip)
          count = math.max(0, count - drips)
        else
          ts = last_ts
        end
      else
        count = 0
      end

      if cost == 0 then
        -- just checking count
        allowed = true
      else
        allowed = (count + cost) <= capacity

        if allowed then
          count = count + cost

          -- time for bucket to empty, in milliseconds
          local ttl = math.ceil(count * msec_per_drip)
          ttl = ttl + 100 -- margin of error, for clock skew

          -- update count and last_ts, with expiration
          state = string.format('%f;%X', count, ts)
          redis.call('SET', key, state, 'PX', ttl)
        end
      end

      return { tostring(count), allowed }
    LUA
    )

    protected def acquire_lock(capacity, cost)
      # timestamp in milliseconds
      ts = (Time.now.to_f * 10**3).to_i

      count, allowed = LUA_SCRIPT.eval(
        redis,
        [ cache_key(key) ],
        [ ts, capacity, @interval_msec, cost ]
      )

      count = count.include?('.') ? count.to_f : count.to_i

      raise Overrated unless allowed

      Lock.new(capacity, count)
    end

    def to_s
      msg = if interval.is_a? Numeric
        if interval == 1
          "every second"
        else
          "every #{interval} seconds"
        end
      else
        "per #{interval}"
      end

      "#<#{self.class}(#{key}: #{capacity} #{msg})>"
    end

  end
end

