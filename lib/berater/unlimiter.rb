module Berater
  class Unlimiter < BaseLimiter

    def initialize(key = :unlimiter, *args, **opts)
      super(key, **opts)
    end

    def limit
      yield if block_given?
    end

  end
end
