module Berater
  class ConcurrencyLimiter < BaseLimiter

    class Incapacitated < Overloaded; end

    attr_reader :capacity, :timeout

    def initialize(capacity, **opts)
      super(**opts)

      self.capacity = capacity
      self.timeout = opts[:timeout] || 0
    end

    def capacity=(capacity)
      unless capacity.is_a? Integer
        raise ArgumentError, "expected Integer, found #{capacity.class}"
      end

      raise ArgumentError, "capacity must be >= 0" unless capacity >= 0

      @capacity = capacity
    end

    def timeout=(timeout)
      unless timeout.is_a? Integer
        raise ArgumentError, "expected Integer, found #{timeout.class}"
      end

      raise ArgumentError, "timeout must be >= 0" unless timeout >= 0

      @timeout = timeout
    end

    class Lock
      attr_reader :limiter, :key, :id

      def initialize(limiter, key, id)
        @limiter = limiter
        @key = key
        @id = id
      end

      def release
        @limiter.release(@id)
      end
    end

    LUA_SCRIPT = <<~LUA.gsub(/^\s*(--.*\n)?/, '')
      local key = KEYS[1]
      local capacity = tonumber(ARGV[1])
      local ttl = tonumber(ARGV[2])

      local exists
      local count
      local lock
      local ts = unpack(redis.call('TIME'))

      -- check to see if key already exists
      if ttl == 0 then
        exists = redis.call('EXISTS', key)
      else
        -- and refresh TTL while we're at it
        exists = redis.call('EXPIRE', key, ttl * 2)
      end

      if exists == 1 then
        -- purge stale hosts
        if ttl > 0 then
          redis.call('ZREMRANGEBYSCORE', key, '-inf', ts - ttl)
        end

        -- check capacity (subtract one for next lock entry)
        count = redis.call('ZCARD', key) - 1

        if count < capacity then
          -- yay, grab a lock

          -- regenerate next lock entry, which has score inf
          lock = unpack(redis.call('ZPOPMAX', key))
          redis.call('ZADD', key, 'inf', (lock + 1) % 2^52)

          count = count + 1
        end
      else
        count = 1
        lock = "1"

        -- create structure to track locks and next id
        redis.call('ZADD', key, 'inf', lock + 1)

        if ttl > 0 then
          redis.call('EXPIRE', key, ttl * 2)
        end
      end

      if lock then
        -- store lock and timestamp
        redis.call('ZADD', key, ts, lock)
      end

      return { count, lock }
    LUA

    def limit(**opts, &block)
      unless opts.empty?
        return self.class.new(
          capacity,
          **options.merge(opts)
          # **options.merge(timeout: timeout).merge(opts)
        ).limit(&block)
      end

      count, lock = redis.eval(LUA_SCRIPT, [ key ], [ capacity, timeout ])

      raise Incapacitated unless lock

      if block_given?
        begin
          yield
        ensure
          release(lock)
        end
      else
        Lock.new(self, key, lock)
      end
    end

    def release(lock)
      if lock.is_a? Lock
        # unwrap
        lock = lock.id
      end

      redis.zrem(key, lock)
    end

  end
end
