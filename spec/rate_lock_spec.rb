describe Berater::Lock do
  it_behaves_like 'a lock', Berater.new(:key, :rate, 3, :second)

  let(:limiter) { Berater.new(:key, :rate, 3, :second) }

  describe '#expired?' do
    let!(:lock) { limiter.limit }

    it 'never expires' do
      expect(lock.locked?).to be true
      expect(lock.expired?).to be false

      Timecop.travel(1_000)

      expect(lock.locked?).to be true
      expect(lock.expired?).to be false
    end
  end

end
