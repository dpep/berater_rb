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

    protected

    def initialize(key, capacity, **opts)
      @key = key
      self.capacity = capacity
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
