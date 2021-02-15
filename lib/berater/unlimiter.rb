module Berater
  class Unlimiter < BaseLimiter

    def initialize(key = :unlimiter, *args, **opts)
      super(key, **opts)
    end

    def limit
      count = redis.incr(cache_key('count'))
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

  end
end
