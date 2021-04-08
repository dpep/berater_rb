module Berater
  private

  class LimiterSet
    include Enumerable

    def initialize
      @limiters = {}
    end

    def each(&block)
      @limiters.each_value(&block)
    end

    def <<(limiter)
      key = limiter.key if limiter.respond_to?(:key)
      send(:[]=, key, limiter)
    end

    def []=(key, limiter)
      unless limiter.is_a? Berater::Limiter
        raise ArgumentError, "expected Berater::Limiter, found: #{limiter}"
      end

      @limiters[key] = limiter
    end

    def [](key)
      @limiters[key]
    end

    def fetch(key, val = default = true, &block)
      args = default ? [ key ] : [ key, val ]
      @limiters.fetch(*args, &block)
    end

    def include?(key)
      if key.is_a? Berater::Limiter
        @limiters.value?(key)
      else
        @limiters.key?(key)
      end
    end

    def clear
      @limiters.clear
    end

    def count
      @limiters.count
    end

    def delete(key)
      if key.is_a? Berater::Limiter
        @limiters.delete(key.key)
      else
        @limiters.delete(key)
      end
    end
    alias remove delete

    def empty?
      @limiters.empty?
    end
  end
end
