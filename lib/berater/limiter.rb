module Berater
  class Limiter

    CONF_TTL = 60 * 60 * 24 * 7 # 1 week

    attr_reader :key, :capacity, :options

    def redis
      options[:redis] || Berater.redis
    end

    def dynamic_limits
      options.fetch(:dynamic_limits, Berater.dynamic_limits) || false
    end

    def limit
      raise NotImplementedError
    end

    def overloaded?
      raise NotImplementedError
    end

    def to_s
      "#<#{self.class}>"
    end

    def save_limits
      limit = [ capacity, *@args ].map(&:to_s).join(':')
      redis.setex(config_key, CONF_TTL, limit)
    end

    def self.load_limits(key, redis: Berater.redis)
      res = redis.get(config_key(key))
      case res
      when "Infinity"
        [ Float::INFINITY ]
      when String
        res.split(':').map(&:to_i)
      end
    end

    protected

    def initialize(key, capacity, *args, **opts)
      @key = key
      self.capacity = capacity
      @args = args
      @options = opts
    end

    def capacity=(capacity)
      unless capacity.is_a?(Integer) || capacity == Float::INFINITY
        raise ArgumentError, "expected Integer, found #{capacity.class}"
      end

      raise ArgumentError, "capacity must be >= 0" unless capacity >= 0

      @capacity = capacity
    end

    def cache_key(key)
      self.class.cache_key(key)
    end

    def self.cache_key(key)
      "Berater:#{key}"
    end

    def config_key
      self.class.config_key(key)
    end

    def self.config_key(key)
      cache_key("#{key}-conf")
    end

    def yield_lock(lock, &block)
      if block_given?
        begin
          yield lock
        ensure
          lock.release
        end
      else
        lock
      end
    end

  end
end
