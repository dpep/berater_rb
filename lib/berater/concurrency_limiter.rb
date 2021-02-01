module Berater
  class ConcurrencyLimiter < BaseLimiter

    class Incapacitated < LimitExceeded; end

    attr_accessor :capacity, :timeout

    def initialize(key, capacity, **opts)
      super(key, **opts)

      self.capacity = capacity
      self.timeout = opts.fetch(:timeout, 0)
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

    LUA_SCRIPT = <<~LUA.gsub(/^\s*(--.*\n)?/, '')
      local key = KEYS[1]
      local capacity = tonumber(ARGV[1])
      local ttl = ARGV[2]
      -- TODO: support ttl of 0

      local count
      local token
      local ts = unpack(redis.call('TIME'))

      -- refresh TTL and check existance of key
      local exists = redis.call('EXPIRE', key, ttl * 2)

      if exists == 1 then
        -- purge stale hosts
        redis.call('ZREMRANGEBYSCORE', key, '-inf', ts - ttl)

        -- check capacity (subtract one for next token entry)
        count = redis.call('ZCARD', key) - 1

        if count < capacity then
          -- yay, grab a token

          -- regenerate next token entry, which has score inf
          token = unpack(redis.call('ZPOPMAX', key))
          redis.call('ZADD', key, 'inf', (token + 1) % 2^52)

          count = count + 1
        end
      else
        -- create structure to track tokens and next id
        redis.call('ZADD', key, 'inf', 2)
        count = 1
        token = "1"

        redis.call('EXPIRE', key, ttl * 2)
      end

      if token then
        -- store token and timestamp
        redis.call('ZADD', key, ts, token)
      end

      return { count, token }
    LUA

    def limit
      count, token = redis.eval(LUA_SCRIPT, [ key ], [ capacity, timeout ])

      raise Incapacitated unless token

      if block_given?
        begin
          yield
        ensure
          release(token)
        end
      else
        token
      end
    end

    def release(token)
      redis.zrem(key, token)
    end

  end
end
