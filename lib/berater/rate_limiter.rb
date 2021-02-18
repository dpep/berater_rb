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
          @interval_str = :second
        when :min, :minute, :minutes
          @interval = 60
          @interval_str = :minute
        when :hour, :hours
          @interval = 60 * 60
          @interval_str = :hour
        else
          raise ArgumentError, "unexpected interval value: #{interval}"
        end
      end

      @interval
    end

    def limit
      ts = Time.now.to_i

      # bucket into time slot
      rkey = "%s:%d" % [ cache_key(key), ts - ts % @interval ]

      count, _ = redis.multi do
        redis.incr rkey
        redis.expire rkey, @interval * 2
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
      msg = if @interval_str
        "per #{@interval_str}"
      else
        if @interval == 1
          "every second"
        else
          "every #{@interval} seconds"
        end
      end

      "#<#{self.class}(#{key}: #{count} #{msg})>"
    end

  end
end

