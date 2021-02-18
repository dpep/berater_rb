require 'berater/version'
require 'berater/lock'


module Berater
  extend self

  class Overloaded < StandardError; end

  MODES = {}

  attr_accessor :redis

  def configure
    yield self
  end

  def new(key, mode = nil, *args, **opts, &block)
    if mode.nil?
      unless args.empty?
        raise ArgumentError, '0 arguments expected with block'
      end

      unless block_given?
        raise ArgumentError, 'expected either mode or block'
      end

      mode, *args = DSL.eval(&block)
    else
      if block_given?
        raise ArgumentError, 'expected either mode or block, not both'
      end
    end

    klass = MODES[mode.to_sym]

    unless klass
      raise ArgumentError, "invalid mode: #{mode}"
    end

    klass.new(key, *args, **opts)
  end

  def register(mode, klass)
    MODES[mode.to_sym] = klass
  end

  def expunge
    redis.scan_each(match: "#{self.name}*") do |key|
      redis.del key
    end
  end

end

# convenience method
def Berater(key, mode, *args, **opts, &block)
  Berater.new(key, mode, *args, **opts).limit(&block)
end

# load and register limiters
require 'berater/base_limiter'
require 'berater/concurrency_limiter'
require 'berater/inhibitor'
require 'berater/rate_limiter'
require 'berater/unlimiter'

Berater.register(:concurrency, Berater::ConcurrencyLimiter)
Berater.register(:inhibited, Berater::Inhibitor)
Berater.register(:rate, Berater::RateLimiter)
Berater.register(:unlimited, Berater::Unlimiter)

require 'berater/dsl'
