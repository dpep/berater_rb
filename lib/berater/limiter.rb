module Berater
  class Limiter

    attr_reader :key, :options

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

    def initialize(key, **opts)
      @key = key
      @options = opts
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
