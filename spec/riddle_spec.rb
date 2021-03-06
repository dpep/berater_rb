# Can you build a rate limiter from a concurrency limiter?  Yes!

class RateRiddler
  def self.limit(capacity, interval)
    lock = Berater::ConcurrencyLimiter.new(:key, capacity, timeout: interval).limit
    yield if block_given?
    # allow lock to time out rather than be released
  end
end


describe 'a ConcurrencyLimiter-derived rate limiter' do
  def limit(&block)
    RateRiddler.limit(1, :second, &block)
  end

  it 'works' do
    expect(limit { 123 }).to eq 123
  end

  it 'respects limits' do
    limit
    expect { limit }.to be_overloaded
  end

  it 'resets over time' do
    limit
    expect { limit }.to be_overloaded

    Timecop.freeze(1)

    limit
    expect { limit }.to be_overloaded
  end
end


# Can you build a concurrency limiter from a rate limiter?  Almost...

class ConcurrenyRiddler
  def self.limit(capacity, timeout: nil)
    timeout ||= 1_000 # fake infinity

    limiter = Berater::RateLimiter.new(:key, capacity, timeout)
    limiter.limit
    yield if block_given?
  ensure
    # decrement counter
    limiter.redis.decr(limiter.send(:cache_key, :key))
  end
end


describe 'a RateLimiter-derived concurrency limiter' do
  def limit(capacity = 1, timeout: nil, &block)
    ConcurrenyRiddler.limit(capacity, timeout: timeout, &block)
  end

  it 'works' do
    expect(limit { 123 }).to eq 123
  end

  it 'respects limits' do
    limit do
      # a second, simultaneous request isn't allowed
      expect { limit }.to be_overloaded
    end

    # but now it'll work
    limit
  end

  it 'resets over time' do
    limit(timeout: 1) do
      expect { limit }.to be_overloaded

      # ...wait for it
      Timecop.freeze(10)

      limit(timeout: 1)
    end
  end

  it "has no memory of the order, so timeouts don't work quite right" do
    limit(2, timeout: 1) do
      Timecop.freeze(0.5)

      limit(2, timeout: 1) do
        # this is where the masquerading breaks.  the first lock is still
        # being held and within it's timeout limit, however the RaterLimiter
        # decremented the count internally since enough time has passed.
        # This next call *should* fail, but doesn't.

        expect {
          expect { limit(2, timeout: 1) }.to be_overloaded
        }.to fail

        # ...close, but not quite!
      end
    end
  end
end
