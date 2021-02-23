module Berater
  class Unlimiter < Limiter

    def initialize(key = :unlimiter, *args, **opts)
      super(key, **opts)
    end

    def limit(**opts, &block)
      yield_lock(Lock.new(self, 0, 0), &block)
    end

  end
end
