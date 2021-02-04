require 'berater/base_limiter'
require 'berater/concurrency_limiter'
require 'berater/inhibitor'
require 'berater/rate_limiter'
require 'berater/unlimiter'
require 'berater/version'


module Berater
  extend self

  Overloaded = BaseLimiter::Overloaded

  MODES = {}

  attr_accessor :redis, :mode

  def configure
    self.mode = :unlimited # default

    yield self
  end

  def new(mode, *args, **opts)
    klass = MODES[mode.to_sym]

    unless klass
      raise ArgumentError, "invalid mode: #{mode}"
    end

    klass.new(*args, **opts)
  end

  def register(mode, klass)
    MODES[mode.to_sym] = klass
  end

  def mode=(mode)
    unless MODES.include? mode.to_sym
      raise ArgumentError, "invalid mode: #{mode}"
    end

    @mode = mode.to_sym
  end

  def limit(*args, **opts, &block)
    mode = opts.delete(:mode) { self.mode }
    new(mode, *args, **opts).limit(&block)
  end

  def expunge
    redis.scan_each(match: "#{self.name}*") do |key|
      redis.del key
    end
  end

end

Berater.register(:concurrency, Berater::ConcurrencyLimiter)
Berater.register(:inhibited, Berater::Inhibitor)
Berater.register(:rate, Berater::RateLimiter)
Berater.register(:unlimited, Berater::Unlimiter)
