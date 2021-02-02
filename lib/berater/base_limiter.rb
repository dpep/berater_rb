module Berater
  class BaseLimiter

    attr_accessor :key, :redis

    def initialize(key, redis:, **opts)
      @key = "#{self.class}:#{key}"
      @redis = redis
    end

    def limit
      raise NotImplementedError
    end

  end
end
