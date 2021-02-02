describe Berater do

  it 'is connected to Redis' do
    expect(Berater.redis.ping).to eq 'PONG'
  end

  it { is_expected.to respond_to :configure }

  describe '.configure' do
    it 'can be set via configure' do
      Berater.configure do |c|
        c.mode = :rate
      end

      expect(Berater.mode).to eq :rate
    end
  end

  describe '.redis' do
    it 'can be reset' do
      expect(Berater.redis).not_to be_nil
      Berater.redis = nil
      expect(Berater.redis).to be_nil
    end
  end

  describe '.mode' do
    it 'validates inputs' do
      expect { Berater.mode = :foo }.to raise_error(ArgumentError)
    end
  end

  context 'unlimited mode' do
    before { Berater.mode = :unlimited }

    describe '.limiter' do
      let(:limiter) { Berater.limiter }

      it 'instantiates an Unlimiter' do
        expect(limiter).to be_a Berater::Unlimiter
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        limiter = Berater.limiter(redis: :fake)
        expect(limiter.redis).not_to be Berater.redis
      end
    end

    describe '.limit' do
      it 'works' do
        expect(Berater.limit).to be_nil
      end

      it 'yields' do
        expect {|b| Berater.limit(&b) }.to yield_control
      end

      it 'never limits' do
        10.times { expect(Berater.limit { 123 } ).to eq 123 }
      end
    end
  end

  context 'rate mode' do
    before { Berater.mode = :rate }

    describe '.limiter' do
      let(:limiter) { Berater.limiter(:key, 1, :second) }

      it 'instantiates a RateLimiter' do
        expect(limiter).to be_a Berater::RateLimiter
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        limiter = Berater.limiter(:key, 1, :second, redis: :fake)
        expect(limiter.redis).not_to be Berater.redis
      end
    end

    describe '.limit' do
      it 'works' do
        expect(Berater.limit(:key, 1, :second)).to eq 1
      end

      it 'yields' do
        expect {|b| Berater.limit(:key, 2, :second, &b) }.to yield_control
        expect(Berater.limit(:key, 2, :second) { 123 }).to eq 123
      end

      it 'limits excessive calls' do
        expect(Berater.limit(:key, 1, :second)).to eq 1

        expect {
          Berater.limit(:key, 1, :second)
        }.to raise_error(Berater::RateLimiter::Overrated)

        # same same
        expect {
          Berater.limit(:key, 1, :second)
        }.to raise_error(Berater::Overloaded)
      end

      it 'accepts options' do
        redis = double('Redis')
        expect(redis).to receive(:multi)

        Berater.limit(:key, 1, :second, redis: redis) rescue nil
      end
    end
  end

  context 'concurrency mode' do
    before { Berater.mode = :concurrency }

    describe '.limiter' do
      let(:limiter) { Berater.limiter(:key, 1) }

      it 'instantiates a ConcurrencyLimiter' do
        expect(limiter).to be_a Berater::ConcurrencyLimiter
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        limiter = Berater.limiter(:key, 1, redis: :fake)
        expect(limiter.redis).not_to be Berater.redis
      end
    end

    describe '.limit' do
      it 'works' do
        expect {|b| Berater.limit(:key, 1, &b) }.to yield_control
      end

      it 'works without blocks by using tokens' do
        token = Berater.limit(:key, 1)
        expect(token).to be_a Berater::ConcurrencyLimiter::Token
        expect(token.release).to be true
      end

      it 'accepts options' do
        redis = double('Redis')
        expect(redis).to receive(:eval)

        Berater.limit(:key, 1, redis: redis) rescue nil
      end
    end
  end

end
