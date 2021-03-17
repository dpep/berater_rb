describe Berater::Limiter do
  it 'can not be initialized' do
    expect { described_class.new }.to raise_error(NoMethodError)
  end

  describe 'abstract methods' do
    let(:limiter) { Class.new(described_class).new(:key, 1) }

    it do
      expect { limiter.limit }.to raise_error(NotImplementedError)
      expect { limiter.utilization }.to raise_error(NotImplementedError)
    end
  end

  describe '#limit' do
    subject { Berater::Unlimiter.new }

    context 'with a capacity parameter' do
      it 'overrides the stored value' do
        is_expected.to receive(:acquire_lock).with(3, anything)

        subject.limit(capacity: 3)
      end

      it 'validates the type' do
        expect {
          subject.limit(capacity: 'abc')
        }.to raise_error(ArgumentError)
      end
    end

    context 'with a cost parameter' do
      it 'overrides the stored value' do
        is_expected.to receive(:acquire_lock).with(anything, 2)

        subject.limit(cost: 2)
      end

      it 'validates' do
        expect {
          subject.limit(cost: 'abc')
        }.to raise_error(ArgumentError)

        expect {
          subject.limit(cost: -1)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#==' do
    let(:limiter)  { Berater::RateLimiter.new(:key, 1, :second) }

    it 'equals itself' do
      expect(limiter).to eq limiter
    end

    it 'equals something with the same initialization parameters' do
      expect(limiter).to eq(
        Berater::RateLimiter.new(:key, 1, :second)
      )
    end

    it 'equals something with equvalent initialization parameters' do
      expect(limiter).to eq(
        Berater::RateLimiter.new(:key, 1, 1)
      )
    end

    it 'does not equal something different' do
      expect(limiter).not_to eq(
        Berater::RateLimiter.new(:key, 2, :second)
      )

      expect(limiter).not_to eq(
        Berater::RateLimiter.new(:keyz, 1, :second)
      )

      expect(limiter).not_to eq(
        Berater::RateLimiter.new(:key, 1, :minute)
      )
    end

    it 'does not equal something altogether different' do
      expect(limiter).not_to eq(
        Berater::ConcurrencyLimiter.new(:key, 1)
      )
    end

    it 'works for ConcurrencyLimiter too' do
      limiter = Berater::ConcurrencyLimiter.new(:key, 1)
      expect(limiter).to eq limiter

      expect(limiter).not_to eq(
        Berater::ConcurrencyLimiter.new(:key, 1, timeout: 1)
      )
    end

    it 'and the others' do
      unlimiter = Berater::Unlimiter.new
      expect(unlimiter).to eq unlimiter

      expect(unlimiter).not_to eq Berater::Inhibitor.new
    end
  end

  describe '#cache_key' do
    subject { klass.new.send(:cache_key, :key) }

    context 'with Unlimiter' do
      let(:klass) { Berater::Unlimiter }

      it do
        is_expected.to eq 'Berater:Unlimiter:key'
      end
    end

    context 'with custom limiter' do
      MyLimiter = Class.new(Berater::Unlimiter)

      let(:klass) { MyLimiter }

      it 'adds Berater prefix' do
        is_expected.to eq 'Berater:MyLimiter:key'
      end
    end
  end

end
