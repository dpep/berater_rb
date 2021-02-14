module Berater
  class RateLimiter < BaseLimiter

    class Overrated < Overloaded; end

    attr_accessor :count, :interval

    def initialize(count, interval, **opts)
      super(**opts)

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

    def limit(**opts, &block)
      unless opts.empty?
        return self.class.new(
          count,
          interval,
          options.merge(opts)
        ).limit(&block)
      end

      ts = Time.now.to_i

      # bucket into time slot
      rkey = "%s:%d" % [ key, ts - ts % @interval ]

      count, _ = redis.multi do
        redis.incr rkey
        redis.expire rkey, @interval * 2
      end

      raise Overrated if count > @count

      if block_given?
        yield
      else
        count
      end
    end

  end
end

