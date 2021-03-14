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
      local count = 0
      local allowed
      local msec_per_drip = interval_msec / capacity

      -- timestamp of last update
      local last_ts = tonumber(redis.call('GET', ts_key))

      if last_ts then
        count = tonumber(redis.call('GET', key)) or 0

        -- adjust for time passing, guarding against clock skew
        if ts > last_ts then
          local drips = math.floor((ts - last_ts) / msec_per_drip)
          count = math.max(0, count - drips)
        else
          ts = last_ts
        end
      end

      if cost == 0 then
        -- just check limit, ie. for .overlimit?
        allowed = count < capacity
      else
        allowed = (count + cost) <= capacity

        if allowed then
          count = count + cost

          -- time for bucket to empty, in milliseconds
          local ttl = math.ceil(count * msec_per_drip)
          ttl = ttl + 100 -- margin of error, for clock skew

          -- update count and last_ts, with expirations
          redis.call('SET', key, count, 'PX', ttl)
          redis.call('SET', ts_key, ts, 'PX', ttl)
        end
      end

      return { count, allowed }
    LUA
    )

    protected def acquire_lock(capacity, cost)
      # timestamp in milliseconds
      ts = (Time.now.to_f * 10**3).to_i

      count, allowed = LUA_SCRIPT.eval(
        redis,
        [ cache_key(key), cache_key("#{key}-ts") ],
        [ ts, capacity, @interval_msec, cost ]
      )

      raise Overrated unless allowed

      Lock.new(capacity, count)
    end

    alias overrated? overloaded?

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

