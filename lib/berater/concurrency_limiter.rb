module Berater
  class ConcurrencyLimiter < Limiter

    class Incapacitated < Overloaded; end

    attr_reader :timeout

    def initialize(key, capacity, **opts)
      super(key, capacity, **opts)

      # round fractional capacity
      self.capacity = capacity.to_i

      self.timeout = opts[:timeout] || 0
    end

    private def timeout=(timeout)
      @timeout = timeout
      timeout = 0 if timeout == Float::INFINITY
      @timeout_msec = Berater::Utils.to_msec(timeout)
    end

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
      local key = KEYS[1]
      local lock_key = KEYS[2]
      local capacity = tonumber(ARGV[1])
      local ts = tonumber(ARGV[2])
      local ttl = tonumber(ARGV[3])
      local cost = tonumber(ARGV[4])
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

        if ttl > 0 then
          redis.call('PEXPIRE', key, ttl)
        end
      end

      return { count, unpack(lock_ids) }
    LUA
    )

    protected def acquire_lock(capacity, cost)
      # round fractional capacity and cost
      capacity = capacity.to_i
      cost = cost.ceil

      # timestamp in milliseconds
      ts = (Time.now.to_f * 10**3).to_i

      count, *lock_ids = LUA_SCRIPT.eval(
        redis,
        [ cache_key(key), cache_key('lock_id') ],
        [ capacity, ts, @timeout_msec, cost ]
      )

      raise Incapacitated if lock_ids.empty?

      release_fn = if cost > 0
        proc { release(lock_ids) }
      end

      Lock.new(capacity, count, release_fn)
    end

    private def release(lock_ids)
      res = redis.zrem(cache_key(key), lock_ids)
      res == true || res == lock_ids.count # depending on which version of Redis
    end

    def to_s
      "#<#{self.class}(#{key}: #{capacity} at a time)>"
    end

  end
end
