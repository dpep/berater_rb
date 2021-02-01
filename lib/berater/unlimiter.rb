module Berater
  class Unlimiter < BaseLimiter

    def initialize(*args, **opts)
      opts[:redis] ||= nil # fake this required arg if need be
      super(self.class.name, **opts)
    end

    def limit
      nil
    end

  end
end
