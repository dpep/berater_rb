describe Berater::Lock do
  it_behaves_like 'a lock', Berater.new(:key, :concurrency, 3)

  let(:limiter) { Berater.new(:key, :concurrency, 3) }

  describe '#expired?' do
    let!(:lock) { limiter.limit }

    context 'when timeout is not set' do
      it { expect(limiter.timeout).to eq 0 }

      it 'never expires' do
        expect(lock.locked?).to be true
        expect(lock.expired?).to be false

        Timecop.travel(1_000)

        expect(lock.locked?).to be true
        expect(lock.expired?).to be false
      end
    end

    context 'when timeout is set and exceeded' do
      before { Timecop.travel(1) }

      let(:limiter) { Berater.new(:key, :concurrency, 3, timeout: 1) }

      it 'expires' do
        expect(lock.expired?).to be true
        expect(lock.locked?).to be false
      end

      it 'fails to release' do
        expect { lock.release }.to raise_error(RuntimeError, /expired/)
      end
    end
  end

end
