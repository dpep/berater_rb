describe Berater::StaticLimiter do
  it_behaves_like 'a limiter', described_class.new(:key, 3)
  it_behaves_like 'a limiter', described_class.new(:key, 3.5)

  describe '#limit' do
    let(:limiter) { described_class.new(:key, 3) }

    it 'limits excessive calls' do
      3.times { limiter.limit }

      expect(limiter).to be_overloaded
    end

    context 'when capacity is a Float' do
      let(:limiter) { described_class.new(:key, 1.5) }

      it 'still works' do
        limiter.limit
        expect(limiter).not_to be_overloaded

        expect { limiter.limit }.to be_overloaded

        limiter.limit(cost: 0.5)
      end
    end

    it 'accepts a dynamic capacity' do
      limiter = described_class.new(:key, 1)

      expect { limiter.limit(capacity: 0) }.to be_overloaded
      5.times { limiter.limit(capacity: 10) }
      expect { limiter }.to be_overloaded
    end

    context 'works with cost parameter' do
      let(:limiter) { described_class.new(:key, 3) }

      it { expect { limiter.limit(cost: 4) }.to be_overloaded }

      it 'works within limit' do
        limiter.limit(cost: 3)
        expect { limiter.limit }.to be_overloaded
      end

      context 'when cost is a Float' do
        it 'still works' do
          2.times { limiter.limit(cost: 1.5) }
          expect(limiter).to be_overloaded
        end

        it 'calculates contention correctly' do
          lock = limiter.limit(cost: 1.5)
          expect(lock.contention).to be 1.5
        end
      end
    end
  end

  describe '#utilization' do
    let(:limiter) { described_class.new(:key, 10) }

    it do
      expect(limiter.utilization).to eq 0

      2.times { limiter.limit }
      expect(limiter.utilization).to eq 20

      8.times { limiter.limit }
      expect(limiter.utilization).to eq 100
    end
  end

  describe '#to_s' do
    let(:limiter) { described_class.new(:key, 3) }

    it { expect(limiter.to_s).to include '3' }
  end

end
