module Berater
  class BaseLimiter

    attr_reader :key, :options

    def redis
      options[:redis] || Berater.redis
    end

    def limit
      raise NotImplementedError
    end

    def to_s
      "#<#{self.class}>"
    end

    protected

    def initialize(key, **opts)
      @key = key
      @options = opts
    end

    def cache_key(key)
      "#{self.class}:#{key}"
    end

  end
end
