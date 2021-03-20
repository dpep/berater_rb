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

  shared_examples 'a Berater' do |klass, capacity, **opts|
    describe '.new' do
      let(:limiter) { Berater.new(:key, capacity, **opts) }

      it 'instantiates the right class' do
        expect(limiter).to be_a klass
      end

      it 'sets the key' do
        expect(limiter.key).to be :key
      end

      it 'inherits redis' do
        expect(limiter.redis).to be Berater.redis
      end

      it 'accepts an optional redis parameter' do
        redis = double('Redis')
        limiter = Berater.new(:key, capacity, opts.merge(redis: redis))
        expect(limiter.redis).to be redis
      end
    end

    describe 'Berater() convenience method' do
      let(:limiter) { Berater(:key, capacity, **opts) }

      it 'creates a limiter' do
        expect(limiter).to be_a klass
      end

      it 'creates an equivalent limiter' do
        expect(limiter).to eq Berater.new(:key, capacity, **opts)
      end

      context 'with a block' do
        before { Berater.test_mode = :pass }

        subject { Berater(:key, capacity, **opts) { 123 } }

        it 'creates a limiter and calls limit' do
          expect(klass).to receive(:new).and_return(limiter)
          expect(limiter).to receive(:limit).and_call_original
          subject
        end

        it 'yields' do
          is_expected.to be 123
        end
      end
    end
  end

  include_examples 'a Berater', Berater::ConcurrencyLimiter, 1, timeout: 1
  include_examples 'a Berater', Berater::Inhibitor, 0
  include_examples 'a Berater', Berater::RateLimiter, 1, interval: :second
  include_examples 'a Berater', Berater::StaticLimiter, 1
  include_examples 'a Berater', Berater::Unlimiter, Float::INFINITY
end
