require 'berater/limiter'
require 'berater/lock'
require 'berater/lua_script'
require 'berater/utils'
require 'berater/version'

module Berater
  extend self

  class Overloaded < StandardError; end

  attr_accessor :redis

  def configure
    yield self
  end

  def reset
    @redis = nil
  end

  def new(key, capacity, **opts)
    args = []

    case capacity
    when Float::INFINITY
      Berater::Unlimiter
    when 0
      Berater::Inhibitor
    else
      if opts[:interval]
        args << opts.delete(:interval)
        Berater::RateLimiter
      else
        Berater::ConcurrencyLimiter
      end
    end.yield_self do |klass|
      args = [ key, capacity, *args ].compact
      klass.new(*args, **opts)
    end
  end

  def expunge
    redis.scan_each(match: "#{self.name}*") do |key|
      redis.del key
    end
  end

end

# convenience method
def Berater(key, capacity, **opts, &block)
  limiter = Berater.new(key, capacity, **opts)
  if block_given?
    limiter.limit(&block)
  else
    limiter
  end
end

# load limiters
require 'berater/concurrency_limiter'
require 'berater/inhibitor'
require 'berater/rate_limiter'
require 'berater/unlimiter'
