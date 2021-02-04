module Berater
  class BaseLimiter

    class Overloaded < RuntimeError; end

    attr_reader :options

    def initialize(**opts)
      @options = opts
    end

    def key
      if options[:key]
        "#{self.class}:#{options[:key]}"
      else
        # default value
        self.class.to_s
      end
    end

    def redis
      options[:redis] || Berater.redis
    end

    def limit(**opts)
      raise NotImplementedError
    end

    def self.limit(*args, **opts, &block)
      self.new(*args, **opts).limit(&block)
    end

  end
end
