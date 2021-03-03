describe Berater do

  it 'is connected to Redis' do
    expect(Berater.redis.ping).to eq 'PONG'
  end

  it { is_expected.to respond_to :configure }

  describe '.configure' do
    it 'is used with a block' do
      Berater.configure do |c|
        c.redis = :redis
      end

      expect(Berater.redis).to be :redis
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
      let(:limiter) { Berater.new(:key, Float::INFINITY) }

      it 'instantiates an Unlimiter' do
        expect(limiter).to be_a Berater::Unlimiter
        expect(limiter.key).to be :key
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:key, Float::INFINITY, redis: redis)
        expect(limiter.redis).to be redis
      end
    end

    context 'inhibited mode' do
      let(:limiter) { Berater.new(:key, 0) }

      it 'instantiates an Inhibitor' do
        expect(limiter).to be_a Berater::Inhibitor
        expect(limiter.key).to be :key
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:key, 0, redis: redis)
        expect(limiter.redis).to be redis
      end
    end

    context 'rate mode' do
      let(:limiter) { Berater.new(:key, 1, :second) }

      it 'instantiates a RateLimiter' do
        expect(limiter).to be_a Berater::RateLimiter
        expect(limiter.key).to be :key
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:key, 1, :second, redis: redis)
        expect(limiter.redis).to be redis
      end
    end

    context 'concurrency mode' do
      let(:limiter) { Berater.new(:key, 1) }

      it 'instantiates a ConcurrencyLimiter' do
        expect(limiter).to be_a Berater::ConcurrencyLimiter
        expect(limiter.key).to be :key
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:key, 1, redis: redis)
        expect(limiter.redis).to be redis
      end
    end
  end

  describe 'convenience method Berater()' do
    RSpec.shared_examples 'test convenience' do |klass, *args|
      it 'creates and calls limit' do
        limiter = double(klass)
        expect(klass).to receive(:new).and_return(limiter)
        expect(limiter).to receive(:limit)

        Berater(:key, *args)
      end
    end

    include_examples 'test convenience', Berater::Unlimiter, Float::INFINITY
    include_examples 'test convenience', Berater::Inhibitor, 0
    include_examples 'test convenience', Berater::RateLimiter, 1, :second
    include_examples 'test convenience', Berater::ConcurrencyLimiter, 1
  end

end
