require 'benchmark'
require 'berater'
require 'redis'

Berater.configure do |c|
  c.redis = Redis.new
end

COUNT = 10_000

Berater.expunge

Benchmark.bmbm(30) do |x|
  x.report('RateLimiter') do
    COUNT.times do |i|
      Berater(:key, COUNT, :second) { i }
    end
  end

  x.report('RateLimiter(dynamic_limits: true)') do
    Berater.new(:key, COUNT * 2, :second).save_limits
    COUNT.times do |i|
      Berater(:key, COUNT, :second, dynamic_limits: true) { i }
    end
  end

  x.report('ConcurrencyLimiter') do
    COUNT.times do |i|
      Berater(:key, COUNT) { i }
    end
  end

  x.report('ConcurrencyLimiter(dynamic_limits: true)') do
    Berater.new(:key, COUNT * 2).save_limits
    COUNT.times do |i|
      Berater(:key, COUNT, dynamic_limits: true) { i }
    end
  end
end

Berater.expunge
