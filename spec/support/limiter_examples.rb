RSpec.shared_examples 'a limiter' do |limiter|

  describe '#limit' do
    it 'yields' do
      expect {|block| limiter.limit(&block) }.to yield_control
    end

    context 'uses a lock' do
      def check(limiter, lock)
        expect(lock).to be_a Berater::Lock
        expect(lock.limiter).to eq limiter
        expect(lock).to respond_to :id
        expect(lock.contention).to be_a Integer
      end

      it 'works inline' do
        check(limiter, limiter.limit)
      end

      it 'works in block mode' do
        limiter.limit {|lock| check(limiter, lock) }
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

end
