describe 'be_overloaded' do
  context 'Berater::Unlimiter' do
    let(:limiter) { Berater::limiter }

    it { expect(limiter).not_to be_overloaded }
    it { expect(limiter).not_to be_overrated }
    it { expect(limiter).not_to be_incapacitated }

    it { expect { limiter }.not_to be_overloaded }
    it { expect { limiter }.not_to be_overrated }
    it { expect { limiter }.not_to be_incapacitated }

    it { expect { limiter.limit }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overrated }
    it { expect { limiter.limit }.not_to be_incapacitated }

    fit 'should warn about improper usage' do
      expect {
        expect { limiter }.to be_overloaded
      }.to raise_error RuntimeError

      expect {
        expect { limiter }.not_to be_overloaded
      }.to raise_error RuntimeError
    end
  end

  context 'Berater::RateLimiter' do
    let(:limiter) { Berater::limiter(:key, 1, :second, mode: :rate) }

    it { expect(limiter).not_to be_overloaded }
    it { expect(limiter).not_to be_overrated }
    it { expect(limiter).not_to be_incapacitated }

    it { expect { limiter.limit }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overrated }
    it { expect { limiter.limit }.not_to be_incapacitated }

    it 'should be_overrated' do
      expect { limiter.limit }.not_to be_overrated

      expect(limiter).to be_overrated
      expect { limiter.limit }.to be_overrated
    end
  end

  context 'Berater::ConcurrencyLimiter' do
    let(:limiter) { Berater::limiter(:key, 1, mode: :concurrency) }

    it { expect { limiter.limit }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overrated }
    it { expect { limiter.limit }.not_to be_incapacitated }

    it 'should be_incapacitated' do
      expect { limiter.limit }.not_to be_incapacitated

      expect(limiter).to be_incapacitated
      expect { limiter.limit }.to be_incapacitated
    end
  end
end
