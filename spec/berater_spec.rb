describe Berater do

  it 'is connected to Redis' do
    expect(Berater.redis.ping).to eq 'PONG'
  end

  it { is_expected.to respond_to :configure }

  describe '.configure' do
    it 'can be set via configure' do
      Berater.configure do |c|
        c.redis = :redis
      end

      expect(Berater.redis).to eq :redis
    end
  end

  describe '.redis' do
    it 'can be reset' do
      expect(Berater.redis).not_to be_nil
      Berater.redis = nil
      expect(Berater.redis).to be_nil
    end
  end

  describe '.new' do
    context 'unlimited mode' do
      let(:limiter) { Berater.new(:unlimited) }

      it 'instantiates an Unlimiter' do
        expect(limiter).to be_a Berater::Unlimiter
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:unlimited, key: 'key', redis: redis)
        expect(limiter.key).to match(/key/)
        expect(limiter.redis).to be redis
      end
    end

    context 'inhibited mode' do
      let(:limiter) { Berater.new(:inhibited) }

      it 'instantiates an Inhibitor' do
        expect(limiter).to be_a Berater::Inhibitor
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:inhibited, key: 'key', redis: redis)
        expect(limiter.key).to match(/key/)
        expect(limiter.redis).to be redis
      end
    end

    context 'rate mode' do
      let(:limiter) { Berater.new(:rate, 1, :second) }

      it 'instantiates a RateLimiter' do
        expect(limiter).to be_a Berater::RateLimiter
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:rate, 1, :second, key: 'key', redis: redis)
        expect(limiter.key).to match(/key/)
        expect(limiter.redis).to be redis
      end
    end

    context 'concurrency mode' do
      let(:limiter) { Berater.new(:concurrency, 1) }

      it 'instantiates a ConcurrencyLimiter' do
        expect(limiter).to be_a Berater::ConcurrencyLimiter
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:concurrency, 1, key: 'key', redis: redis)
        expect(limiter.key).to match(/key/)
        expect(limiter.redis).to be redis
      end
    end
  end

end
