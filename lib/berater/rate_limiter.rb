module Berater
  class RateLimiter < Limiter

    class Overrated < Overloaded; end

    attr_accessor :interval

    def initialize(key, capacity, interval, **opts)
      super(key, capacity, **opts)

      self.interval = interval
    end

    private def interval=(interval)
      @interval = interval
      @interval_usec = Berater::Utils.to_usec(interval)
    end

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
      local key = KEYS[1]
      local ts_key = KEYS[2]
      local ts = tonumber(ARGV[1])
      local capacity = tonumber(ARGV[2])
      local interval_usec = tonumber(ARGV[3])
      local cost = tonumber(ARGV[4])

      local count = 0
      local usec_per_drip = interval_usec / capacity

      -- timestamp of last update
      local last_ts = tonumber(redis.call('GET', ts_key))

      if last_ts then
        count = tonumber(redis.call('GET', key)) or 0

        -- adjust for time passing
        local drips = math.floor((ts - last_ts) / usec_per_drip)
        count = math.max(0, count - drips)
      end

      local allowed = (count + cost) <= capacity

      if allowed and cost > 0 then
        count = count + cost

        -- time for bucket to empty, in milliseconds
        local ttl = math.ceil((count * usec_per_drip) / 1000)

        -- update count and last_ts, with expirations
        redis.call('SET', key, count, 'PX', ttl)
        redis.call('SET', ts_key, ts, 'PX', ttl)
      end

      return { count, allowed }
    LUA
    )

    def limit(capacity: nil, cost: 1, &block)
      capacity ||= @capacity

      # timestamp in microseconds
      ts = (Time.now.to_f * 10**6).to_i

      count, allowed = LUA_SCRIPT.eval(
        redis,
        [ cache_key(key), cache_key("#{key}-ts") ],
        [ ts, capacity, @interval_usec, cost ]
      )

      raise Overrated unless allowed

      lock = Lock.new(self, ts, count)
      yield_lock(lock, &block)
    end

    def overloaded?
      limit(cost: 0) { |lock| lock.contention >= capacity }
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

