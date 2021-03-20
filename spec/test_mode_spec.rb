describe Berater::TestMode do
  context 'after test_mode.rb has been loaded' do
    it 'monkey patches Berater' do
      expect(Berater).to respond_to(:test_mode)
    end

    it 'defaults to off' do
      expect(Berater.test_mode).to be nil
    end

    it 'prepends Limiter subclasses' do
      expect(Berater::Unlimiter.ancestors).to include(Berater::Limiter::TestMode)
      expect(Berater::Inhibitor.ancestors).to include(Berater::Limiter::TestMode)
    end

    it 'preserves the original functionality via super' do
      expect { Berater::Limiter.new }.to raise_error(NoMethodError)
    end
  end

  describe '.test_mode' do
    it 'can be turned on' do
      Berater.test_mode = :pass
      expect(Berater.test_mode).to be :pass

      Berater.test_mode = :fail
      expect(Berater.test_mode).to be :fail
    end

    it 'can be turned off' do
      Berater.test_mode = nil
      expect(Berater.test_mode).to be nil
    end

    it 'validates input' do
      expect { Berater.test_mode = :foo }.to raise_error(ArgumentError)
    end

    it 'works no matter when limiter was created' do
      limiter = Berater::Unlimiter.new
      expect(limiter).not_to be_overloaded

      Berater.test_mode = :fail
      expect(limiter).to be_overloaded
    end

    it 'supports a generic expectation' do
      Berater.test_mode = :pass
      expect_any_instance_of(Berater::Limiter).to receive(:limit)
      Berater::Unlimiter.new.limit
    end
  end

  describe '.reset' do
    before { Berater.test_mode = :pass }

    it 'resets test_mode' do
      expect(Berater.test_mode).to be :pass
      Berater.reset
      expect(Berater.test_mode).to be nil
    end
  end

  shared_examples 'it supports test_mode' do
    before do
      # without hitting Redis
      Berater.redis = nil
      expect_any_instance_of(Berater::LuaScript).not_to receive(:eval)
    end

    context 'with test_mode = :pass' do
      before { Berater.test_mode = :pass }

      it_behaves_like 'it is not overloaded'

      it 'always works' do
        10.times { subject.limit }
      end
    end

    context 'with test_mode = :fail' do
      before { Berater.test_mode = :fail }

      it_behaves_like 'it is overloaded'
    end
  end

  describe 'Unlimiter' do
    subject { Berater::Unlimiter.new }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it_behaves_like 'it is not overloaded'
    end

    it_behaves_like 'it supports test_mode'
  end

  describe 'Inhibitor' do
    subject { Berater::Inhibitor.new }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it_behaves_like 'it is overloaded'
    end

    it_behaves_like 'it supports test_mode'
  end

  describe 'RateLimiter' do
    subject { Berater::RateLimiter.new(:key, 1, :second) }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it_behaves_like 'it is not overloaded'

      it 'works per usual' do
        expect(Berater::RateLimiter::LUA_SCRIPT).to receive(:eval).twice.and_call_original
        expect(subject.limit).to be_a Berater::Lock
        expect { subject.limit }.to be_overloaded
      end
    end

    it_behaves_like 'it supports test_mode'
  end

  describe 'ConcurrencyLimiter' do
    subject { Berater::ConcurrencyLimiter.new(:key, 1) }

    context 'when test_mode = nil' do
      before { Berater.test_mode = nil }

      it_behaves_like 'it is not overloaded'

      it 'works per usual' do
        expect(Berater::ConcurrencyLimiter::LUA_SCRIPT).to receive(:eval).twice.and_call_original
        expect(subject.limit).to be_a Berater::Lock
        expect { subject.limit }.to be_overloaded
      end
    end

    it_behaves_like 'it supports test_mode'
  end

end
