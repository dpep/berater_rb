module Berater
  class RateLimiter < Limiter

    class Overrated < Overloaded; end

    attr_accessor :interval

    def initialize(key, capacity, interval, **opts)
      self.interval = interval

      super(key, capacity, @interval_usec, **opts)
    end

    private def interval=(interval)
      @interval = interval
      @interval_usec = Berater::Utils.to_usec(interval)
    end

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
      local key = KEYS[1]
      local ts_key = KEYS[2]
      local conf_key = KEYS[3]
      local ts = tonumber(ARGV[1])
      local capacity = tonumber(ARGV[2])
      local interval_usec = tonumber(ARGV[3])
      local cost = tonumber(ARGV[4])
      local count = 0
      local allowed

      if conf_key then
        local config = redis.call('GET', conf_key)

        if config then
          -- use dynamic capacity limit
          capacity, interval_usec = string.match(config, "(%d+):(%d+)")
          capacity = tonumber(capacity)
          interval_usec = tonumber(interval_usec)

          -- reset ttl for a week
          redis.call('EXPIRE', conf_key, 604800)
        end
      end

      local usec_per_drip = interval_usec / capacity

      -- timestamp of last update
      local last_ts = tonumber(redis.call('GET', ts_key))

      if last_ts then
        count = tonumber(redis.call('GET', key)) or 0

        -- adjust for time passing
        local drips = math.floor((ts - last_ts) / usec_per_drip)
        count = math.max(0, count - drips)
      end

      if cost == 0 then
        -- just check limit, ie. for .overlimit?
        allowed = count < capacity
      else
        allowed = (count + cost) <= capacity

        if allowed then
          count = count + cost

          -- time for bucket to empty, in milliseconds
          local ttl = math.ceil((count * usec_per_drip) / 1000)

          -- update count and last_ts, with expirations
          redis.call('SET', key, count, 'PX', ttl)
          redis.call('SET', ts_key, ts, 'PX', ttl)
        end
      end

      return { count, allowed }
    LUA
    )

    def limit(capacity: nil, cost: 1, &block)
      limit_key = if capacity.nil? && dynamic_limits
        config_key
      end
      capacity ||= @capacity

      # timestamp in microseconds
      ts = (Time.now.to_f * 10**6).to_i

      count, allowed = LUA_SCRIPT.eval(
        redis,
        [ cache_key(key), cache_key("#{key}-ts"), limit_key ],
        [ ts, capacity, @interval_usec, cost ]
      )

      raise Overrated unless allowed

      lock = Lock.new(self, ts, count)
      yield_lock(lock, &block)
    end

    def overloaded?
      limit(cost: 0) { false }
    rescue Overrated
      true
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

