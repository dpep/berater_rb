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
      expect { subject.release }.to raise_error(RuntimeError)
    end
  end

  context 'when enough time passes' do
    before { Timecop.freeze(1) }

    it 'expires' do
      expect(subject.expired?).to be true
    end

    it 'fails to release' do
      expect { subject.release }.to raise_error(RuntimeError)
    end

    it { expect(subject.release?).to be false }
  end

end
