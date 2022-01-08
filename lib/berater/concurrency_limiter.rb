module Berater
  class ConcurrencyLimiter < Limiter
    PRIORITY_RANGE = 1..5

    def initialize(key, capacity, **opts)
      super(key, capacity, **opts)

      # truncate fractional capacity
      self.capacity = capacity.to_i

      self.timeout = opts[:timeout] || 0
    end

    def timeout
      options[:timeout]
    end

    private def timeout=(timeout)
      timeout = 0 if timeout == Float::INFINITY
      @timeout = Berater::Utils.to_msec(timeout)
    end

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
      local key = KEYS[1]
      local lock_key = KEYS[2]
      local priorities_key = KEYS[3]
      local capacity = tonumber(ARGV[1])
      local ts = tonumber(ARGV[2])
      local ttl = tonumber(ARGV[3])
      local cost = tonumber(ARGV[4])
      local priority = tonumber(ARGV[5])
      local lock_ids = {}

      -- purge stale hosts
      if ttl > 0 then
        redis.call('ZREMRANGEBYSCORE', key, 0, ts - ttl)
      end

      -- check capacity
      local count = redis.call('ZCARD', key)

      if cost == 0 then
        -- just checking count
        table.insert(lock_ids, true)
      elseif (count + cost) <= capacity then
        if priority and ((count + cost) >= (capacity * 0.8)) then
          -- compare priority against recent requests
          local priorities = redis.call('LRANGE', priorities_key, 0, capacity)
          local sum = 0

          for _, p in ipairs(priorities) do
            sum = sum + p
          end

          if #priorities > 0 and priority > (sum / #priorities) then
            -- not important enough given limited capacity
            return count
          end
        end

        -- grab locks, one per cost
        local lock_id = redis.call('INCRBY', lock_key, cost)
        local locks = {}

        for i = lock_id - cost + 1, lock_id do
          table.insert(lock_ids, i)

          table.insert(locks, ts)
          table.insert(locks, i)
        end

        redis.call('ZADD', key, unpack(locks))
        count = count + cost

        if priority then
          -- record priority and trim list size
          redis.call('LPUSH', priorities_key, priority)
          redis.call('LTRIM', priorities_key, 0, capacity)
        end

        if ttl > 0 then
          redis.call('PEXPIRE', key, ttl)
          redis.call('PEXPIRE', priorities_key, ttl)
        end
      end

      return { count, unpack(lock_ids) }
    LUA
    )

    protected def acquire_lock(capacity:, cost:, priority: nil)
      # round fractional capacity and cost
      capacity = capacity.to_i
      cost = cost.ceil

      if priority.is_a?(String)
        # try casting
        priority = Float(priority) rescue nil
      end

      priority = nil unless PRIORITY_RANGE.include?(priority)
      # shedding_threshold = 0.95 * capacity if priority

      # timestamp in milliseconds
      ts = (Time.now.to_f * 10**3).to_i

      count, *lock_ids = LUA_SCRIPT.eval(
        redis,
        [ cache_key, self.class.cache_key('lock_id'), self.class.cache_key('priorities') ],
        [ capacity, ts, @timeout, cost, priority ]
      )

      raise Overloaded if lock_ids.empty?

      release_fn = if cost > 0
        proc { redis.zrem(cache_key, lock_ids) }
      end

      Lock.new(capacity, count, release_fn)
    end

    def to_s
      "#<#{self.class}(#{key}: #{capacity} at a time)>"
    end

  end
end
