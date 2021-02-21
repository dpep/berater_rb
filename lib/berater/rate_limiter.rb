module Berater
  class RateLimiter < BaseLimiter

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

    def limit
      ts = Time.now.to_i

      # bucket into time slot
      rkey = "%s:%d" % [ cache_key(key), ts - ts % @interval_sec ]

      count, _ = redis.multi do
        redis.incr rkey
        redis.expire rkey, @interval_sec * 2
      end

      raise Overrated if count > @count

      lock = Lock.new(self, count, count)

      if block_given?
        begin
          yield lock
        ensure
          lock.release
        end
      else
        lock
      end
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

