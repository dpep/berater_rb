describe Berater::ConcurrencyLimiter::Lock do
  subject { Berater.limit(1, timeout: 1) }

  before { Berater.mode = :concurrency }

  it { expect(subject.released?).to be false }
  it { expect(subject.expired?).to be false }

  context 'after being released' do
    before { subject.release }

    it { expect(subject.released?).to be true }
    it { expect(subject.expired?).to be false }

    it 'can not be released again' do
      expect { subject.release }.to raise_error(RuntimeError, /already/)
    end
  end

  context 'when enough time passes' do
    before { subject; Timecop.freeze(2) }

    it 'expires' do
      expect(subject.expired?).to be true
    end

    it 'fails to release' do
      expect { subject.release }.to raise_error(RuntimeError, /expired/)
    end

    it { expect(subject.released?).to be false }
  end

  describe '#contention' do
    let(:limiter) { Berater.new(:concurrency, 3) }

    it 'tracks contention' do
      lock_1 = limiter.limit
      expect(lock_1.contention).to eq 1

      lock_2 = limiter.limit
      expect(lock_2.contention).to eq 2

      limiter.limit do |lock_3|
        expect(lock_3.contention).to eq 3
      end
    end
  end

end
