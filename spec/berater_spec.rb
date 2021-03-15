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
    context 'Unlimiter mode' do
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

    context 'Inhibitor mode' do
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
      let(:limiter) { Berater.new(:key, 1, interval: :second) }

      it 'instantiates a RateLimiter' do
        expect(limiter).to be_a Berater::RateLimiter
        expect(limiter.key).to be :key
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts options' do
        redis = double('Redis')
        limiter = Berater.new(:key, 1, interval: :second, redis: redis)
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

  describe 'Berater() - convenience method' do
    RSpec.shared_examples 'test convenience' do |klass, capacity, **opts|
      it 'creates a limiter' do
        limiter = Berater(:key, capacity, **opts)
        expect(limiter).to be_a klass
      end

      context 'with a block' do
        it 'creates a limiter and calls limit' do
          limiter = Berater(:key, capacity, **opts)
          expect(klass).to receive(:new).and_return(limiter)
          expect(limiter).to receive(:limit).and_call_original

          begin
            res = Berater(:key, capacity, **opts) { true }
            expect(res).to be true
          rescue Berater::Overloaded
            expect(klass).to be Berater::Inhibitor
          end
        end
      end
    end

    include_examples 'test convenience', Berater::Unlimiter, Float::INFINITY
    include_examples 'test convenience', Berater::Inhibitor, 0
    include_examples 'test convenience', Berater::RateLimiter, 1, interval: :second
    include_examples 'test convenience', Berater::ConcurrencyLimiter, 1
  end

end
