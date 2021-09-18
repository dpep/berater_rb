module Berater
  class Limiter

    attr_reader :key, :capacity, :options

    def redis
      options[:redis] || Berater.redis
    end

    def limit(capacity: nil, cost: 1, &block)
      capacity ||= @capacity
      lock = nil

      Berater.middleware.call(self, capacity: capacity, cost: cost) do |limiter, **opts|
        lock = limiter.inner_limit(**opts)
      end

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

    protected def inner_limit(capacity:, cost:)
      unless capacity.is_a?(Numeric) && capacity >= 0
        raise ArgumentError, "invalid capacity: #{capacity}"
      end

      unless cost.is_a?(Numeric) && cost >= 0 && cost < Float::INFINITY
        raise ArgumentError, "invalid cost: #{cost}"
      end

      acquire_lock(capacity, cost)
    rescue NoMethodError => e
      raise unless e.message.include?("undefined method `evalsha' for")

      # repackage error so it's easier to understand
      raise RuntimeError, "invalid redis connection: #{redis}"
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

    def cache_key(subkey = nil)
      instance_key = subkey.nil? ? key : "#{key}:#{subkey}"
      self.class.cache_key(instance_key)
    end

    class << self
      def new(*args, **kwargs)
        # can only call via subclass
        raise NoMethodError if self == Berater::Limiter

        if RUBY_VERSION < '3' && kwargs.empty?
          # avoid ruby 2 problems with empty hashes
          super(*args)
        else
          super
        end
      end

      def cache_key(key)
        klass = to_s.split(':')[-1]
        "Berater:#{klass}:#{key}"
      end

      protected

      def inherited(subclass)
        # automagically create convenience method
        name = subclass.to_s.split(':')[-1]

        Berater.define_singleton_method(name) do |*args, **opts, &block|
          Berater::Utils.convenience_fn(subclass, *args, **opts, &block)
        end
      end
    end

  end
end
