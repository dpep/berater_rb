module Berater
  module Utils
    extend self

    refine Object do
      def to_msec
        Berater::Utils.to_msec(self)
      end
    end

    def to_msec(val)
      res = val

      if val.is_a? String
        # naively attempt casting, otherwise maybe it's a keyword
        res = Float(val) rescue val.to_sym
      end

      if res.is_a? Symbol
        case res
        when :sec, :second, :seconds
          res = 1
        when :min, :minute, :minutes
          res = 60
        when :hour, :hours
          res = 60 * 60
        end
      end

      unless res.is_a? Numeric
        raise ArgumentError, "unexpected value: #{val}"
      end

      if res < 0
        raise ArgumentError, "expected value >= 0, found: #{val}"
      end

      if res == Float::INFINITY
        raise ArgumentError, "infinite values not allowed"
      end

      (res * 10**3).to_i
    end

    def convenience_fn(klass, *args, **opts, &block)
      limiter = klass.new(*args, **opts)
      block ? limiter.limit(&block) : limiter
    end
  end
end
