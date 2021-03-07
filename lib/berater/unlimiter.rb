module Berater
  class Unlimiter < Limiter

    def initialize(key = :unlimiter, *args, **opts)
      super(key, Float::INFINITY, **opts)
    end

    def limit(**opts, &block)
      yield_lock(Lock.new(Float::INFINITY, 0), &block)
    end

    def overloaded?
      false
    end

  end
end
