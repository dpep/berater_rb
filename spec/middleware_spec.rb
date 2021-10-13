class Meddler
  def call(*args, **kwargs)
    yield
  end
end

describe 'Berater.middleware' do
  subject { Berater.middleware }

  describe 'adding middleware' do
    after { is_expected.to include Meddler }

    it 'can be done inline' do
      Berater.middleware.use Meddler
    end

    it 'can be done with a block' do
      Berater.middleware do
        use Meddler
      end
    end
  end

  it 'resets along with Berater' do
    Berater.middleware.use Meddler
    is_expected.to include Meddler

    Berater.reset
    is_expected.to be_empty
  end

  describe 'Berater::Limiter#limit' do
    let(:middleware) { Meddler.new }
    let(:limiter) { Berater::ConcurrencyLimiter.new(:key, 1) }

    before do
      expect(Meddler).to receive(:new).and_return(middleware).at_least(1)
      Berater.middleware.use Meddler
    end

    it 'calls the middleware' do
      expect(middleware).to receive(:call)
      limiter.limit
    end

    it 'calls the middleware, passing the limiter and options' do
      expect(middleware).to receive(:call).with(
        limiter,
        hash_including(:capacity, :cost)
      )

      limiter.limit
    end

    context 'when used per ususual' do
      before do
        expect(middleware).to receive(:call).and_call_original.at_least(1)
      end

      it 'still works inline' do
        expect(limiter.limit).to be_a Berater::Lock
      end

      it 'still works in block mode' do
        expect(limiter.limit { 123 }).to be 123
      end

      it 'still has limits' do
        limiter.limit
        expect(limiter).to be_overloaded
      end
    end

    context 'when middleware meddles' do
      it 'can change the capacity' do
        expect(middleware).to receive(:call) do |limiter, **opts, &block|
          opts[:capacity] = 0
          block.call(limiter, **opts)
        end

        expect { limiter.limit }.to be_overloaded
      end

      it 'can change the cost' do
        expect(middleware).to receive(:call) do |limiter, **opts, &block|
          opts[:cost] = 2
          block.call(limiter, **opts)
        end

        expect { limiter.limit }.to be_overloaded
      end

      it 'can change the limiter' do
        other_limiter = Berater::Inhibitor.new

        expect(middleware).to receive(:call) do |limiter, **opts, &block|
          block.call(other_limiter, **opts)
        end
        expect(other_limiter).to receive(:acquire_lock).and_call_original

        expect { limiter.limit }.to be_overloaded
      end

      it 'can abort by not yielding' do
        expect(middleware).to receive(:call)
        expect(limiter.limit).to be nil
      end

      it 'can intercept the lock' do
        expect(middleware).to receive(:call) do |&block|
          lock = block.call
          expect(lock).to be_a Berater::Lock
          expect(lock.capacity).to eq limiter.capacity
        end

        limiter.limit
      end
    end
  end
end
