module Berater
  class Limiter

    attr_reader :key, :capacity, :options

    def redis
      options[:redis] || Berater.redis
    end

    def limit(capacity: nil, cost: 1, &block)
      capacity ||= @capacity

      unless capacity.is_a?(Numeric) && capacity >= 0
        raise ArgumentError, "invalid capacity: #{capacity}"
      end

      unless cost.is_a?(Numeric) && cost >= 0 && cost < Float::INFINITY
        raise ArgumentError, "invalid cost: #{cost}"
      end

      lock = acquire_lock(capacity, cost)

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

    def utilization
      lock = limit(cost: 0)

      if lock.capacity == 0
        1.0
      else
        lock.contention.to_f / lock.capacity
      end
    rescue Berater::Overloaded
      1.0
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
      raise NoMethodError if self == Berater::Limiter

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

    def acquire_lock(capacity, cost)
      raise NotImplementedError
    end

    def cache_key(key)
      klass = self.class.to_s.split(':')[-1]
      "Berater:#{klass}:#{key}"
    end

  end
end
