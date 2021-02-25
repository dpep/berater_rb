require 'berater/test_mode'

describe 'Berater.test_mode' do
  after { Berater.test_mode = nil }

  describe 'Unlimiter' do
    subject { Berater::Unlimiter.new }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it { is_expected.to be_a Berater::Unlimiter }

      it 'works per usual' do
        expect {|block| subject.limit(&block) }.to yield_control
        10.times { expect(subject.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it { is_expected.to be_a Berater::Unlimiter }
      it_behaves_like 'it is not overloaded'

      it 'always works' do
        10.times { expect(subject.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it { is_expected.to be_a Berater::Unlimiter }
      it_behaves_like 'it is overloaded'
    end
  end

  describe 'Inhibitor' do
    subject { Berater::Inhibitor.new }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it { is_expected.to be_a Berater::Inhibitor }

      it 'works per usual' do
        expect { subject }.to be_overloaded
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it { is_expected.to be_a Berater::Inhibitor }
      it_behaves_like 'it is not overloaded'

      it 'always works' do
        10.times { expect(subject.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it { is_expected.to be_a Berater::Inhibitor }
      it_behaves_like 'it is overloaded'
    end
  end

  describe 'RateLimiter' do
    subject { Berater::RateLimiter.new(:key, 1, :second) }

    shared_examples 'a RateLimiter' do
      it { is_expected.to be_a Berater::RateLimiter }

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
        expect(subject.limit).to be_a Berater::Lock
        expect { subject.limit }.to be_overloaded
      end

      it 'yields per usual' do
        expect {|block| subject.limit(&block) }.to yield_control
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it_behaves_like 'a RateLimiter'
      it_behaves_like 'it is not overloaded'

      it 'always works and without calling redis' do
        expect(Berater::RateLimiter::LUA_SCRIPT).not_to receive(:eval)
        10.times { expect(subject.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it_behaves_like 'a RateLimiter'

      it 'never works and without calling redis' do
        expect(Berater::RateLimiter::LUA_SCRIPT).not_to receive(:eval)
        expect { subject }.to be_overloaded
      end
    end
  end

  describe 'ConcurrencyLimiter' do
    subject { Berater::ConcurrencyLimiter.new(:key, 1) }

    shared_examples 'a ConcurrencyLimiter' do
      it { expect(subject).to be_a Berater::ConcurrencyLimiter }

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
        expect(subject.limit).to be_a Berater::Lock
        expect { subject.limit }.to be_overloaded
      end

      it 'yields per usual' do
        expect {|block| subject.limit(&block) }.to yield_control
      end
    end

    context 'when test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it_behaves_like 'a ConcurrencyLimiter'
      it_behaves_like 'it is not overloaded'

      it 'always works and without calling redis' do
        expect(Berater::ConcurrencyLimiter::LUA_SCRIPT).not_to receive(:eval)
        10.times { expect(subject.limit).to be_a Berater::Lock }
      end
    end

    context 'when test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it_behaves_like 'a ConcurrencyLimiter'
      it_behaves_like 'it is overloaded'

      it 'never works and without calling redis' do
        expect(Berater::ConcurrencyLimiter::LUA_SCRIPT).not_to receive(:eval)
        expect { subject }.to be_overloaded
      end
    end
  end

end
