describe 'be_overloaded' do
  context 'Berater::Unlimiter' do
    let(:limiter) { Berater.new(:unlimited) }

    it { expect(limiter).not_to be_overloaded }
    it { expect(limiter).not_to be_overrated }
    it { expect(limiter).not_to be_incapacitated }

    it { expect { limiter }.not_to be_overloaded }
    it { expect { limiter }.not_to be_overrated }
    it { expect { limiter }.not_to be_incapacitated }

    it { expect { limiter.limit }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overrated }
    it { expect { limiter.limit }.not_to be_incapacitated }
  end

  context 'Berater::RateLimiter' do
    let(:limiter) { Berater.new(:rate, 1, :second) }

    it { expect(limiter).not_to be_overloaded }
    it { expect(limiter).not_to be_overrated }
    it { expect(limiter).not_to be_incapacitated }

    it { expect { limiter }.not_to be_overloaded }
    it { expect { limiter }.not_to be_overrated }
    it { expect { limiter }.not_to be_incapacitated }

    it { expect { limiter.limit }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overrated }
    it { expect { limiter.limit }.not_to be_incapacitated }

    context 'once limit is used up' do
      before { limiter.limit }

      it 'should be_overrated' do
        expect(limiter).to be_overrated
      end

      it 'should be_overrated' do
        expect { limiter }.to be_overrated
      end

      it 'should be_overrated' do
        expect { limiter.limit }.to be_overrated
      end
    end
  end

  context 'Berater::ConcurrencyLimiter' do
    let(:limiter) { Berater.new(:concurrency, 1) }

    it { expect(limiter).not_to be_overloaded }
    it { expect(limiter).not_to be_overrated }
    it { expect(limiter).not_to be_incapacitated }

    it { expect { limiter }.not_to be_overloaded }
    it { expect { limiter }.not_to be_overrated }
    it { expect { limiter }.not_to be_incapacitated }

    it { expect { limiter.limit }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overrated }
    it { expect { limiter.limit }.not_to be_incapacitated }

    context 'when lock is released' do
      it 'should be_incapacitated' do
        3.times do
          expect(limiter).not_to be_incapacitated
        end
      end

      it 'should be_incapacitated' do
        3.times do
          expect { limiter }.not_to be_incapacitated
        end
      end

      it 'should be_incapacitated' do
        3.times do
          expect { limiter.limit {} }.not_to be_incapacitated
        end
      end
    end

    context 'when lock is *not* released' do
      it 'should be_incapacitated' do
        expect { limiter.limit }.not_to be_incapacitated
        expect { limiter.limit }.to be_incapacitated
      end

      it 'should be_incapacitated' do
        expect { 3.times { limiter.limit } }.to be_incapacitated
      end
    end
  end
end
