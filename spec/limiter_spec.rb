describe Berater::Limiter do

  it 'can not be initialized' do
    expect { described_class.new }.to raise_error(NotImplementedError)
  end

  describe '==' do
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

end
