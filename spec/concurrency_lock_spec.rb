describe Berater::ConcurrencyLimiter::Lock do
  let(:limiter) { Berater.new(:key, :concurrency, 3) }

  describe '#contention' do
    it 'tracks contention' do
      lock_1 = limiter.limit
      expect(lock_1.contention).to eq 1

      lock_2 = limiter.limit
      expect(lock_2.contention).to eq 2

      limiter.limit do |lock_3|
        expect(lock_3.contention).to eq 3
      end
    end

    it 'works in block mode' do
      lock_1 = limiter.limit

      limiter.limit do |lock_2|
        expect(lock_1.contention).to eq 1
        expect(lock_2.contention).to eq 2
      end
    end
  end

  describe '#release' do
    it 'can not be released twice' do
      lock = limiter.limit
      expect(lock.release).to be true
      expect { lock.release }.to raise_error(RuntimeError, /already/)
    end

    it 'does not work in block mode' do
      expect do
        limiter.limit do |lock|
          lock.release
        end
      end.to raise_error(RuntimeError, /already/)
    end
  end

  describe '#released?' do
    it 'works' do
      lock = limiter.limit
      expect(lock.released?).to be false

      lock.release
      expect(lock.released?).to be true
    end

    it 'works in block mode' do
      limiter.limit do |lock|
        expect(lock.released?).to be false
      end
    end
  end

  describe '#expired?' do
    let!(:lock) { limiter.limit }

    context 'when timeout is not set' do
      it { expect(limiter.timeout).to eq 0 }

      it 'never expires' do
        expect(lock.expired?).to be false

        Timecop.travel(1_000)

        expect(lock.expired?).to be false
      end
    end

    context 'when timeout is set and exceeded' do
      before { Timecop.travel(1) }

      let(:limiter) { Berater.new(:key, :concurrency, 3, timeout: 1) }

      it 'expires' do
        expect(lock.expired?).to be true
      end

      it 'fails to release' do
        expect(lock.released?).to be false
        expect { lock.release }.to raise_error(RuntimeError, /expired/)
      end
    end
  end

end
