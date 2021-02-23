module Berater
  class ConcurrencyLimiter < Limiter

    class Incapacitated < Overloaded; end

    attr_reader :capacity, :timeout

    def initialize(key, capacity, **opts)
      super(key, **opts)

      self.capacity = capacity
      self.timeout = opts[:timeout] || 0
    end

    private def capacity=(capacity)
      unless capacity.is_a? Integer
        raise ArgumentError, "expected Integer, found #{capacity.class}"
      end

      raise ArgumentError, "capacity must be >= 0" unless capacity >= 0

      @capacity = capacity
    end

    private def timeout=(timeout)
      unless timeout.is_a? Integer
        raise ArgumentError, "expected Integer, found #{timeout.class}"
      end

      raise ArgumentError, "timeout must be >= 0" unless timeout >= 0

      @timeout = timeout
    end

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
      local key = KEYS[1]
      local lock_key = KEYS[2]
      local capacity = tonumber(ARGV[1])
      local ts = tonumber(ARGV[2])
      local ttl = tonumber(ARGV[3])
      local lock

      -- purge stale hosts
      if ttl > 0 then
        redis.call('ZREMRANGEBYSCORE', key, '-inf', ts - ttl)
      end

      -- check capacity
      local count = redis.call('ZCARD', key)

      if count < capacity then
        -- grab a lock
        lock = redis.call('INCR', lock_key)
        redis.call('ZADD', key, ts, lock)
        count = count + 1
      end

      return { count, lock }
    LUA
    )

    def limit(&block)
      count, lock_id = LUA_SCRIPT.eval(
        redis,
        [ cache_key(key), cache_key('lock_id') ],
        [ capacity, Time.now.to_i, timeout ]
      )

      raise Incapacitated unless lock_id

      lock = Lock.new(self, lock_id, count, -> { release(lock_id) })

      yield_lock(lock, &block)
    end

    private def release(lock_id)
      res = redis.zrem(cache_key(key), lock_id)
      res == true || res == 1 # depending on which version of Redis
    end

    def to_s
      "#<#{self.class}(#{key}: #{capacity} at a time)>"
    end

  end
end
