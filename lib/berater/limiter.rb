module Berater
  class Limiter

    attr_reader :key, :capacity, :options

    def redis
      options[:redis] || Berater.redis
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

    def ==(other)
      self.class == other.class &&
      self.key == other.key &&
      self.capacity == other.capacity &&
      self.args == other.args &&
      self.options == other.options &&
      self.redis.connection == other.redis.connection
    end

    def self.new(*)
      # can only call via subclass
      raise NotImplementedError if self == Berater::Limiter

      super
    end

    protected

    attr_reader :args

    def initialize(key, capacity, *args, **opts)
      @key = key
      self.capacity = capacity
      @args = args
      @options = opts
    end

    def capacity=(capacity)
      unless capacity.is_a?(Numeric)
        raise ArgumentError, "expected Numeric, found #{capacity.class}"
      end

      if capacity == Float::INFINITY
        raise ArgumentError, 'infinite capacity not supported, use Unlimiter'
      end

      raise ArgumentError, 'capacity must be >= 0' unless capacity >= 0

      @capacity = capacity
    end

    def cache_key(key)
      "#{self.class}:#{key}"
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
