module Berater
  class Limiter
    DEFAULT_COST = 1

    attr_reader :key, :capacity, :options

    def redis
      options[:redis] || Berater.redis
    end

    def limit(**opts, &block)
      opts[:capacity] ||= @capacity
      opts[:cost] ||= DEFAULT_COST

      lock = Berater.middleware.call(self, **opts) do |limiter, **opts|
        limiter.inner_limit(**opts)
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

    protected def inner_limit(capacity:, cost:, **opts)
      if capacity.is_a?(String)
        # try casting
        begin
          capacity = Float(capacity)
        rescue ArgumentError; end
      end

      unless capacity.is_a?(Numeric) && capacity >= 0
        raise ArgumentError, "invalid capacity: #{capacity}"
      end

      if cost.is_a?(String)
        # try casting
        begin
          cost = Float(cost)
        rescue ArgumentError; end
      end

      unless cost.is_a?(Numeric) && cost >= 0 && cost < Float::INFINITY
        raise ArgumentError, "invalid cost: #{cost}"
      end

      acquire_lock(capacity: capacity, cost: cost, **opts)
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
      if capacity.is_a?(String)
        # try casting
        begin
          capacity = Float(capacity)
        rescue TypeError, ArgumentError; end
      end

      unless capacity.is_a?(Numeric)
        raise ArgumentError, "expected Numeric, found #{capacity.class}"
      end

      if capacity == Float::INFINITY
        raise ArgumentError, 'infinite capacity not supported, use Unlimiter'
      end

      raise ArgumentError, 'capacity must be >= 0' unless capacity >= 0

      @capacity = capacity
    end

    def acquire_lock(capacity:, cost:)
      raise NotImplementedError
    end

    def cache_key
      self.class.cache_key(key)
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
