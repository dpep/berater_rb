require 'berater/test_mode'

describe 'Berater.test_mode' do
  after { Berater.test_mode = nil }

  describe 'Unlimiter' do
    let(:limiter) { Berater::Unlimiter.new }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it { expect(limiter).to be_a Berater::Unlimiter }

      it 'works per usual' do
        expect {|block| limiter.limit(&block) }.to yield_control
        10.times { expect(limiter.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it { expect(limiter).to be_a Berater::Unlimiter }

      it 'always works' do
        expect {|block| limiter.limit(&block) }.to yield_control
        10.times { expect(limiter.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it { expect(limiter).to be_a Berater::Unlimiter }

      it 'never works' do
        expect { limiter }.to be_overloaded
      end
    end
  end

  describe 'Inhibitor' do
    let(:limiter) { Berater::Inhibitor.new }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it { expect(limiter).to be_a Berater::Inhibitor }

      it 'works per usual' do
        expect { limiter }.to be_overloaded
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it { expect(limiter).to be_a Berater::Inhibitor }

      it 'always works' do
        expect {|block| limiter.limit(&block) }.to yield_control
        10.times { expect(limiter.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it { expect(limiter).to be_a Berater::Inhibitor }

      it 'never works' do
        expect { limiter }.to be_overloaded
      end
    end
  end

  describe 'RateLimiter' do
    let(:limiter) { Berater::RateLimiter.new(:key, 1, :second) }

    shared_examples 'a RateLimiter' do
      it { expect(limiter).to be_a Berater::RateLimiter }

      it 'checks arguments' do
        expect {
          Berater::RateLimiter.new(:key, 1)
        }.to raise_error(ArgumentError)
      end
    end

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it_behaves_like 'a RateLimiter'

      it 'works per usual' do
        expect(Berater::RateLimiter::LUA_SCRIPT).to receive(:eval).twice.and_call_original
        expect(limiter.limit).to be_a Berater::Lock
        expect { limiter.limit }.to be_overloaded
      end

      it 'yields per usual' do
        expect {|block| limiter.limit(&block) }.to yield_control
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it_behaves_like 'a RateLimiter'

      it 'always works and without calling redis' do
        expect(Berater::RateLimiter::LUA_SCRIPT).not_to receive(:eval)
        expect {|block| limiter.limit(&block) }.to yield_control
        10.times { expect(limiter.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it_behaves_like 'a RateLimiter'

      it 'never works and without calling redis' do
        expect(Berater::RateLimiter::LUA_SCRIPT).not_to receive(:eval)
        expect { limiter }.to be_overloaded
      end
    end
  end

  describe 'ConcurrencyLimiter' do
    let(:limiter) { Berater::ConcurrencyLimiter.new(:key, 1) }

    shared_examples 'a ConcurrencyLimiter' do
      it { expect(limiter).to be_a Berater::ConcurrencyLimiter }

      it 'checks arguments' do
        expect {
          Berater::ConcurrencyLimiter.new(:key, 1.0)
        }.to raise_error(ArgumentError)
      end
    end

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it_behaves_like 'a ConcurrencyLimiter'

      it 'works per usual' do
        expect(Berater::ConcurrencyLimiter::LUA_SCRIPT).to receive(:eval).twice.and_call_original
        expect(limiter.limit).to be_a Berater::Lock
        expect { limiter.limit }.to be_overloaded
      end

      it 'yields per usual' do
        expect {|block| limiter.limit(&block) }.to yield_control
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it_behaves_like 'a ConcurrencyLimiter'

      it 'always works and without calling redis' do
        expect(Berater::ConcurrencyLimiter::LUA_SCRIPT).not_to receive(:eval)
        expect {|block| limiter.limit(&block) }.to yield_control
        10.times { expect(limiter.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it_behaves_like 'a ConcurrencyLimiter'

      it 'never works and without calling redis' do
        expect(Berater::ConcurrencyLimiter::LUA_SCRIPT).not_to receive(:eval)
        expect { limiter }.to be_overloaded
      end
    end
  end

end
