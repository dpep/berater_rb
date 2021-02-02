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

    class Token
      attr_reader :limiter, :token

      def initialize(limiter, token)
        @limiter = limiter
        @token = token
      end

      def release
        @limiter.release(@token)
      end
    end

    LUA_SCRIPT = <<~LUA.gsub(/^\s*(--.*\n)?/, '')
      local key = KEYS[1]
      local capacity = tonumber(ARGV[1])
      local ttl = tonumber(ARGV[2])

      local exists
      local count
      local token
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
        count = 1
        token = "1"

        -- create structure to track tokens and next id
        redis.call('ZADD', key, 'inf', token + 1)

        if ttl > 0 then
          redis.call('EXPIRE', key, ttl * 2)
        end
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
        Token.new(self, token)
      end
    end

    def release(token)
      if token.is_a? Token
        # unwrap
        token = token.token
      end

      redis.zrem(key, token)
    end

  end
end
