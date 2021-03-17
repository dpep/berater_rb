module Berater
  class Unlimiter < Limiter

    def initialize(key = :unlimiter, *args, **opts)
      super(key, Float::INFINITY, **opts)
    end

    def to_s
      "#<#{self.class}>"
    end

    protected

    def capacity=(*)
      @capacity = Float::INFINITY
    end

    def acquire_lock(*)
      Lock.new(Float::INFINITY, 0)
    end

  end
end
