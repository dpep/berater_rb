require 'berater/base_limiter'
require 'berater/version'


module Berater
  extend self

  autoload 'RateLimiter', 'berater/rate_limiter'
  autoload 'ConcurrencyLimiter', 'berater/concurrency_limiter'
  autoload 'Unlimiter', 'berater/unlimiter'

  class Overloaded < RuntimeError; end

  MODES = [ :rate, :concurrency, :unlimited ]

  attr_accessor :redis, :mode

  def configure
    self.mode = :unlimited # default

    yield self
  end

  def mode=(mode)
    unless MODES.include? mode.to_sym
      raise ArgumentError, "invalide #{name} mode: #{mode}"
    end

    @mode = mode.to_sym
  end

  def limiter(*args, **opts)
    mode = opts.delete(:mode) { self.mode }

    klass = case mode
      when :rate
        RateLimiter
      when :concurrency
        ConcurrencyLimiter
      when :unlimited
        Unlimiter
      else
        raise
    end

    klass.new(*args, **opts)
  end

  def limit(*args, **opts, &block)
    limiter(*args, **opts).limit(&block)
  end

  def self.expunge
    redis.scan_each(match: "#{self.name}*") do |key|
      redis.del key
    end
  end

end
