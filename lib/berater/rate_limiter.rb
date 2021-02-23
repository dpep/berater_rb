module Berater
  class RateLimiter < Limiter

    class Overrated < Overloaded; end

    attr_accessor :count, :interval

    def initialize(key, count, interval, **opts)
      super(key, **opts)

      self.count = count
      self.interval = interval
    end

    private def count=(count)
      unless count.is_a? Integer
        raise ArgumentError, "expected Integer, found #{count.class}"
      end

      raise ArgumentError, "count must be >= 0" unless count >= 0

      @count = count
    end

    private def interval=(interval)
      @interval = interval.dup

      case @interval
      when Integer
        raise ArgumentError, "interval must be >= 0" unless @interval >= 0
        @interval_sec = @interval
      when String
        @interval = @interval.to_sym
      when Symbol
      else
        raise ArgumentError, "unexpected interval type: #{interval.class}"
      end

      if @interval.is_a? Symbol
        case @interval
        when :sec, :second, :seconds
          @interval = :second
          @interval_sec = 1
        when :min, :minute, :minutes
          @interval = :minute
          @interval_sec = 60
        when :hour, :hours
          @interval = :hour
          @interval_sec = 60 * 60
        else
          raise ArgumentError, "unexpected interval value: #{interval}"
        end
      end
    end

    LUA_SCRIPT = <<~LUA.gsub(/^\s*|\s*--.*/, '')
      local key = KEYS[1]
      local ts_key = KEYS[2]
      local ts = tonumber(ARGV[1])
      local capacity = tonumber(ARGV[2])
      local usec_per_drip = tonumber(ARGV[3])
      local cost = tonumber(ARGV[4])
      local count = 0

      -- timestamp of last update
      local last_ts = tonumber(redis.call('GET', ts_key))

      if last_ts then
        count = tonumber(redis.call('GET', key)) or 0

        -- adjust for time passing
        local drips = math.floor((ts - last_ts) / usec_per_drip)
        count = math.max(0, count - drips)
      end

      local allowed = (count + cost) <= capacity

      if allowed then
        count = count + cost

        -- time for bucket to empty, in milliseconds
        local ttl = math.ceil((count * usec_per_drip) / 1000)

        -- update count and last_ts, with expirations
        redis.call('SET', key, count, 'PX', ttl)
        redis.call('SET', ts_key, ts, 'PX', ttl)
      end

      return { count, allowed }
    LUA

    def limit(capacity: nil, cost: 1, &block)
      capacity ||= @count
      usec_per_drip = (@interval_sec * 10**6) / @count

      # timestamp in microseconds
      ts = (Time.now.to_f * 10**6).to_i

      count, allowed = redis.eval(
        LUA_SCRIPT,
        [ cache_key(key), cache_key("#{key}-ts") ],
        [ ts, capacity, usec_per_drip, cost ]
      )

      raise Overrated unless allowed

      lock = Lock.new(self, "#{ts}-#{count}", count)

      yield_lock(lock, &block)
    end

    def to_s
      msg = if @interval.is_a? Integer
        if @interval == 1
          "every second"
        else
          "every #{@interval} seconds"
        end
      else
        "per #{@interval}"
      end

      "#<#{self.class}(#{key}: #{count} #{msg})>"
    end

  end
end

