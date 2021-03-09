describe Berater::ConcurrencyLimiter do
  it_behaves_like 'a limiter', described_class.new(:key, 1)
  it_behaves_like 'a limiter', described_class.new(:key, 1, timeout: 1)

  describe '.new' do
    let(:limiter) { described_class.new(:key, 1) }

    it 'initializes' do
      expect(limiter.key).to be :key
      expect(limiter.capacity).to be 1
    end

    it 'has default values' do
      expect(limiter.redis).to be Berater.redis
    end
  end

  describe '#capacity' do
    def expect_capacity(capacity)
      limiter = described_class.new(:key, capacity)
      expect(limiter.capacity).to eq capacity
    end

    it { expect_capacity(0) }
    it { expect_capacity(1) }
    it { expect_capacity(1.5) }
    it { expect_capacity(10_000) }

    context 'with erroneous values' do
      def expect_bad_capacity(capacity)
        expect do
          described_class.new(:key, capacity)
        end.to raise_error ArgumentError
      end

      it { expect_bad_capacity(-1) }
      it { expect_bad_capacity('1') }
      it { expect_bad_capacity(:one) }
    end
  end

  describe '#timeout' do
    # see spec/utils_spec.rb

    it 'saves the interval in original and millisecond format' do
      limiter = described_class.new(:key, 1, timeout: 3)
      expect(limiter.timeout).to be 3
      expect(limiter.instance_variable_get(:@timeout_msec)).to be (3 * 10**3)
    end

    it 'handles infinity' do
      limiter = described_class.new(:key, 1, timeout: Float::INFINITY)
      expect(limiter.timeout).to be Float::INFINITY
      expect(limiter.instance_variable_get(:@timeout_msec)).to be 0
    end
  end

  describe '#limit' do
    let(:limiter) { described_class.new(:key, 2, timeout: 30) }

    it 'works' do
      expect {|b| limiter.limit(&b) }.to yield_control
    end

    it 'works many times if workers release locks' do
      30.times do
        expect {|b| limiter.limit(&b) }.to yield_control
      end

      30.times do
        lock = limiter.limit
        lock.release
      end
    end

    it 'limits excessive calls' do
      expect(limiter.limit).to be_a Berater::Lock
      expect(limiter.limit).to be_a Berater::Lock

      expect(limiter).to be_incapacitated
    end

    context 'with capacity 0' do
      let(:limiter) { described_class.new(:key, 0) }

      it 'always fails' do
        expect(limiter).to be_incapacitated
      end
    end

    context 'when capacity is a Float' do
      let(:limiter) { described_class.new(:key, 1.5) }

      it 'still works' do
        lock = limiter.limit

        # since fractional cost is not supported
        expect(lock.capacity).to be 1
        expect(limiter).to be_incapacitated
      end
    end

    it 'limit resets over time' do
      2.times { limiter.limit }
      expect(limiter).to be_incapacitated

      Timecop.freeze(30)

      2.times { limiter.limit }
      expect(limiter).to be_incapacitated
    end

    it 'limit resets with millisecond precision' do
      2.times { limiter.limit }
      expect(limiter).to be_incapacitated

      # travel forward to just before first lock times out
      Timecop.freeze(29.999)
      expect(limiter).to be_incapacitated

      # traveling one more millisecond will decrement the count
      Timecop.freeze(0.001)
      2.times { limiter.limit }
      expect(limiter).to be_incapacitated
    end

    it 'accepts a dynamic capacity' do
      expect { limiter.limit(capacity: 0) }.to be_incapacitated
      5.times { limiter.limit(capacity: 10) }
      expect { limiter }.to be_incapacitated
    end

    context 'with cost parameter' do
      it { expect { limiter.limit(cost: 4) }.to be_incapacitated }

      it 'works within limit' do
        limiter.limit(cost: 2)
        expect(limiter).to be_incapacitated
      end

      it 'releases full cost' do
        lock = limiter.limit(cost: 2)
        expect(limiter).to be_incapacitated

        lock.release
        expect(limiter).not_to be_incapacitated

        lock = limiter.limit(cost: 2)
        expect(limiter).to be_incapacitated
      end

      it 'respects timeout' do
        limiter.limit(cost: 2)
        expect(limiter).to be_incapacitated

        Timecop.freeze(30)
        expect(limiter).not_to be_incapacitated

        limiter.limit(cost: 2)
        expect(limiter).to be_incapacitated
      end

      context 'with fractional costs' do
        it 'rounds up' do
          limiter.limit(cost: 1.5)
          expect(limiter).to be_incapacitated
        end

        it 'accumulates correctly' do
          limiter.limit(cost: 0.5) # => 1
          limiter.limit(cost: 0.7) # => 2
          expect(limiter).to be_incapacitated
        end
      end

      it 'only allows positive values' do
        expect { limiter.limit(cost: -1) }.to raise_error(ArgumentError)
      end
    end

    context 'with same key, different limiters' do
      let(:limiter_one) { described_class.new(:key, 1) }
      let(:limiter_two) { described_class.new(:key, 1) }

      it { expect(limiter_one.key).to eq limiter_two.key }

      it 'works as expected' do
        expect(limiter_one.limit).to be_a Berater::Lock

        expect(limiter_one).to be_incapacitated
        expect(limiter_two).to be_incapacitated
      end
    end

    context 'with same key, different capacities' do
      let(:limiter_one) { described_class.new(:key, 1) }
      let(:limiter_two) { described_class.new(:key, 2) }

      it { expect(limiter_one.capacity).not_to eq limiter_two.capacity }

      it 'works as expected' do
        one_lock = limiter_one.limit
        expect(one_lock).to be_a Berater::Lock

        expect(limiter_one).to be_incapacitated
        expect(limiter_two).not_to be_incapacitated

        two_lock = limiter_two.limit
        expect(two_lock).to be_a Berater::Lock

        expect(limiter_one).to be_incapacitated
        expect(limiter_two).to be_incapacitated

        one_lock.release
        expect(limiter_one).to be_incapacitated
        expect(limiter_two).not_to be_incapacitated

        two_lock.release
        expect(limiter_one).not_to be_incapacitated
        expect(limiter_two).not_to be_incapacitated
      end
    end

    context 'with different keys, different limiters' do
      let(:limiter_one) { described_class.new(:one, 1) }
      let(:limiter_two) { described_class.new(:two, 1) }

      it 'works as expected' do
        expect(limiter_one).not_to be_incapacitated
        expect(limiter_two).not_to be_incapacitated

        one_lock = limiter_one.limit
        expect(one_lock).to be_a Berater::Lock

        expect(limiter_one).to be_incapacitated
        expect(limiter_two).not_to be_incapacitated

        two_lock = limiter_two.limit
        expect(two_lock).to be_a Berater::Lock

        expect(limiter_one).to be_incapacitated
        expect(limiter_two).to be_incapacitated
      end
    end
  end

  describe '#overloaded?' do
    let(:limiter) { described_class.new(:key, 1, timeout: 30) }

    it 'works' do
      expect(limiter.overloaded?).to be false
      lock = limiter.limit
      expect(limiter.overloaded?).to be true
      lock.release
      expect(limiter.overloaded?).to be false
    end

    it 'respects timeout' do
      expect(limiter.overloaded?).to be false
      lock = limiter.limit
      expect(limiter.overloaded?).to be true
      Timecop.freeze(30)
      expect(limiter.overloaded?).to be false
    end
  end

  describe '#to_s' do
    def check(capacity, expected)
      expect(
        described_class.new(:key, capacity).to_s
      ).to match(expected)
    end

    it 'works' do
      check(1, /1 at a time/)
      check(3, /3 at a time/)
    end
  end

end
