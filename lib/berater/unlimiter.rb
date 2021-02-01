module Berater
  class Unlimiter < BaseLimiter

    def initialize(*args, **opts)
      opts[:redis] ||= nil # fake this required arg if need be
      super(self.class.name, **opts)
    end

    def limit
      yield if block_given?
    end

  end
end
