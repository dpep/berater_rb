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

    class Token
      attr_reader :limiter, :key, :token

      def initialize(limiter, key, token)
        @limiter = limiter
        @key = key
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

    def limit(**opts, &block)
      unless opts.empty?
        return self.class.new(
          capacity,
          **options.merge(opts)
          # **options.merge(timeout: timeout).merge(opts)
        ).limit(&block)
      end

      count, token = redis.eval(LUA_SCRIPT, [ key ], [ capacity, timeout ])

      raise Incapacitated unless token

      if block_given?
        begin
          yield
        ensure
          release(token)
        end
      else
        Token.new(self, key, token)
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
