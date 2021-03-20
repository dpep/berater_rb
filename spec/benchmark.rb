require 'benchmark'
require 'berater'
require 'redis'

Berater.configure do |c|
  c.redis = Redis.new
end

COUNT = 10_000

Benchmark.bmbm(30) do |x|
  x.report('RateLimiter') do
    COUNT.times do |i|
      Berater::RateLimiter(:key, COUNT, :second) { i }
    end
  end

  x.report('ConcurrencyLimiter') do
    COUNT.times do |i|
      Berater::ConcurrencyLimiter(:key, COUNT) { i }
    end
  end

  x.report('ConcurrencyLimiter(timeout)') do
    COUNT.times do |i|
      Berater::ConcurrencyLimiter(:key, COUNT, timeout: 30) { i }
    end
  end

  x.report('StaticLimiter') do
    COUNT.times do |i|
      Berater::StaticLimiter(:key, COUNT) { i }
    end
  end
end

Berater.expunge
