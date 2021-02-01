describe Berater do

  it 'is connected to Redis' do
    expect(Berater.redis.ping).to eq 'PONG'
  end

  it { is_expected.to respond_to :configure }

  it 'permits redis to be reset' do
    Berater.redis = nil
    expect(Berater.redis).to be_nil
  end

  describe '.mode' do
    subject { Berater.mode }

    it 'has a "rate" mode' do
      Berater.configure do |c|
        c.mode = :rate
      end

      is_expected.to eq :rate
    end

    it 'validates inputs' do
      expect { Berater.mode = :foo }.to raise_error(ArgumentError, /foo/)
    end
  end

  describe '.limiter' do
    context 'base case' do
      let(:limiter) { Berater.limiter }

      it 'instantiates an Unlimiter by default' do
        expect(limiter).to be_a Berater::Unlimiter
      end

      it 'inheriets the Berater Redis connection' do
        expect(limiter.redis).to be Berater.redis
      end
    end

    context 'with some options' do
      it 'accepts a new redis connection' do
        fake_redis = :redis
        limiter = Berater.limiter(redis: fake_redis)

        expect(limiter.redis).to be fake_redis
      end
    end
  end

end
