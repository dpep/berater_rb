RSpec.shared_examples 'a limiter' do |limiter|

  describe '#initialize' do
    it 'has a key' do
      expect(limiter.key).not_to be nil
    end

    it 'has a capacity' do
      expect(limiter.capacity).to be_a(Numeric).or(be Float::INFINITY)
    end

    it 'has a redis' do
      expect(limiter).to respond_to(:redis)
    end

    it 'has options' do
      expect(limiter.options).to be_a Hash
    end
  end

  describe '#limit' do
    it 'yields' do
      expect {|block| limiter.limit(&block) }.to yield_control
    end

    it 'yields a value' do
      res = limiter.limit { 123 }
      expect(res).to eq 123
    end

    context 'uses a lock' do
      def check(limiter, lock)
        expect(lock).to be_a Berater::Lock
        expect(lock.capacity).to eq limiter.capacity
        expect(lock.contention).to be_a Numeric
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
        lock.release
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

  describe '#utilization' do
    it 'returns a Float' do
      expect(limiter.utilization).to be_a Float
    end
  end

  describe 'convenience method' do
    subject do
      Berater.send(method_name, *params, **limiter.options)
    end

    let(:method_name) { limiter.class.name.split(':')[-1] }
    let(:params) {
      [
        limiter.key,
        limiter.capacity,
        *limiter.send(:args),
      ]
    }

    it 'exists' do
      expect(Berater).to respond_to method_name
    end

    it 'constructs a limiter' do
      is_expected.to be_a Berater::Limiter
    end

    it 'constructs an equivalent limiter' do
      is_expected.to eq limiter
    end

    it 'accepts a block' do
      Berater.test_mode = :pass

      expect(
        Berater.send(method_name, *params) { 123 }
      ).to be 123
    end
  end

end
