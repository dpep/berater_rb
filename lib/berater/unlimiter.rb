module Berater
  class Unlimiter < Limiter

    def initialize(key = :unlimiter, *args, **opts)
      super(key, 0, **opts)
    end

    def limit(**opts, &block)
      yield_lock(Lock.new(self, 0, 0), &block)
    end

    def overloaded?
      false
    end

  end
end
