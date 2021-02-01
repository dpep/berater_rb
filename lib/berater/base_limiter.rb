module Berater
  class BaseLimiter

    attr_accessor :key, :redis

    def initialize(key, redis:, **opts)
      @key = key.to_s
      @redis = redis
    end

    def limit
      raise NotImplementedError
    end

  end
end
