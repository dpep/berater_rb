module Berater
  class RateLimiter < Limiter

    class Overrated < Overloaded; end

    attr_accessor :capacity, :interval

    def initialize(key, capacity, interval, **opts)
      super(key, **opts)

      self.capacity = capacity
      self.interval = interval
    end

    private def capacity=(capacity)
      unless capacity.is_a? Integer
        raise ArgumentError, "expected Integer, found #{capacity.class}"
      end

      raise ArgumentError, "capacity must be >= 0" unless capacity >= 0

      @capacity = capacity
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

    LUA_SCRIPT = Berater::LuaScript(<<~LUA
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
      usec_per_drip = (@interval_sec * 10**6) / @capacity

      # timestamp in microseconds
      ts = (Time.now.to_f * 10**6).to_i

      count, allowed = LUA_SCRIPT.eval(
        redis,
        [ cache_key(key), cache_key("#{key}-ts") ],
        [ ts, capacity, usec_per_drip, cost ]
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
      msg = if @interval.is_a? Integer
        if @interval == 1
          "every second"
        else
          "every #{@interval} seconds"
        end
      else
        "per #{@interval}"
      end

      "#<#{self.class}(#{key}: #{capacity} #{msg})>"
    end

  end
end

