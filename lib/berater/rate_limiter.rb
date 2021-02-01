module Berater
  class RateLimiter < BaseLimiter

    attr_accessor :count, :interval

    def initialize(key, count, interval, **opts)
      super(key, **opts)

      self.count = count
      self.interval = interval
    end

    def count=(count)
      unless count.is_a? Integer
        raise ArgumentError, "expected Integer, found #{count.class}"
      end

      raise ArgumentError, "count must be >= 0" unless count >= 0

      @count = count
    end

    def interval=(interval)
      @interval = interval.dup

      case @interval
      when Integer
        raise ArgumentError, "interval must be >= 0" unless @interval >= 0
      when String
        @interval = @interval.to_sym
      when Symbol
      else
        raise ArgumentError, "unexpected interval type: #{interval.class}"
      end

      if @interval.is_a? Symbol
        case @interval
        when :sec, :second, :seconds
          @interval = 1
        when :min, :minute, :minutes
          @interval = 60
        when :hour, :hours
          @interval = 60 * 60
        else
          raise ArgumentError, "unexpected interval value: #{interval}"
        end
      end

      @interval
    end

    def limit
      ts = Time.now.to_i

      # bucket into time slot
      rkey = "%s:%s:%d" % [ self.class, key, ts - ts % @interval ]

      count, _ = redis.multi do
        redis.incr rkey
        redis.expire rkey, @interval * 2
      end

      raise LimitExceeded if count > @count

      count
    end

  end
end
