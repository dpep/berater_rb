require 'berater/limiter'
require 'berater/lock'
require 'berater/lua_script'
require 'berater/utils'
require 'berater/version'
require 'meddleware'

module Berater
  extend self

  class Overloaded < StandardError; end

  attr_accessor :redis

  def configure
    yield self
  end

  def reset
    @redis = nil
    middleware.clear
  end

  def middleware(&block)
    (@middleware ||= Meddleware.new).tap do
      @middleware.instance_eval(&block) if block_given?
    end
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
      elsif opts[:timeout]
        Berater::ConcurrencyLimiter
      else
        Berater::StaticLimiter
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
def Berater(*args, **opts, &block)
  Berater::Utils.convenience_fn(Berater, *args, **opts, &block)
end

# load limiters
require 'berater/concurrency_limiter'
require 'berater/inhibitor'
require 'berater/rate_limiter'
require 'berater/static_limiter'
require 'berater/unlimiter'
