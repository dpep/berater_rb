module Berater
  class Unlimiter < Limiter

    def initialize(key = :unlimiter, *args, **opts)
      super(key, **opts)
    end

    def limit
      lock = Lock.new(self, 0, 0)

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

  end
end
