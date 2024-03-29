module Berater
  module Middleware
    class LoadShedder
      PRIORITY_RANGE = 1..5

      def initialize(default_priority: nil)
        @default_priority = default_priority
      end

      def call(*args, **opts)
        if priority = opts.delete(:priority) || @default_priority
          opts[:capacity] = adjust_capacity(opts[:capacity], priority)
        end

        yield *args, **opts
      end

      protected

      def adjust_capacity(capacity, priority)
        if priority.is_a?(String)
          # try casting
          priority = Float(priority) rescue nil
        end

        if PRIORITY_RANGE.include?(priority)
          # priority 1 stays at 100%, 2 scales down to 90%, 5 to 60%
          factor = 1 - (priority - 1) * 0.1

          (capacity * factor).floor
        else
          capacity
        end
      end
    end
  end
end
