require 'berater/dsl'

describe Berater do
  using Berater::DSL

  it 'instatiates an Unlimiter' do
    limiter = Berater.new(:key) { unlimited }
    expect(limiter).to be_a Berater::Unlimiter
    expect(limiter.key).to be :key
  end

  it 'instatiates an Inhibiter' do
    limiter = Berater.new(:key) { inhibited }
    expect(limiter).to be_a Berater::Inhibitor
    expect(limiter.key).to be :key
  end

  it 'instatiates a RateLimiter' do
    limiter = Berater.new(:key) { 1.per second }
    expect(limiter).to be_a Berater::RateLimiter
    expect(limiter.key).to be :key
    expect(limiter.capacity).to be 1
    expect(limiter.interval).to be :second
  end

  it 'instatiates a ConcurrencyLimiter' do
    limiter = Berater.new(:key, timeout: 2) { 1.at_once }
    expect(limiter).to be_a Berater::ConcurrencyLimiter
    expect(limiter.key).to be :key
    expect(limiter.capacity).to be 1
    expect(limiter.timeout).to be 2
  end

  it 'does not accept mode/args and dsl block' do
    expect {
      Berater.new(:key, :rate) { 1.per second }
    }.to raise_error(ArgumentError)

    expect {
      Berater.new(:key, :concurrency, 2) { 3.at_once }
    }.to raise_error(ArgumentError)
  end

  it 'requires either mode or dsl block' do
    expect {
      Berater.new(:key)
    }.to raise_error(ArgumentError)
  end

end
