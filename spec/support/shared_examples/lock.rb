RSpec.shared_examples "a lock" do |limiter|

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

  describe '#locked?' do
    it 'works' do
      lock = limiter.limit
      expect(lock.locked?).to be true

      lock.release
      expect(lock.locked?).to be false
    end

    it 'works in block mode' do
      limiter.limit do |lock|
        expect(lock.locked?).to be true
      end
    end
  end

end
