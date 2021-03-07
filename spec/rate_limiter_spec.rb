describe Berater::RateLimiter do
  it_behaves_like 'a limiter', Berater.new(:key, 3, :second)

  describe '.new' do
    let(:limiter) { described_class.new(:key, 1, :second) }

    it 'initializes' do
      expect(limiter.key).to be :key
      expect(limiter.capacity).to eq 1
      expect(limiter.interval).to eq :second
    end

    it 'has default values' do
      expect(limiter.redis).to be Berater.redis
    end
  end

  describe '#capacity' do
    def expect_capacity(capacity)
      limiter = described_class.new(:key, capacity, :second)
      expect(limiter.capacity).to eq capacity
    end

    it { expect_capacity(0) }
    it { expect_capacity(1) }
    it { expect_capacity(1.5) }
    it { expect_capacity(100) }

    context 'with erroneous values' do
      def expect_bad_capacity(capacity)
        expect do
          described_class.new(:key, capacity, :second)
        end.to raise_error ArgumentError
      end

      # it { expect_bad_capacity(0.5) }
      it { expect_bad_capacity(-1) }
      it { expect_bad_capacity('1') }
      it { expect_bad_capacity(:one) }
    end
  end

  describe '#interval' do
    # see spec/utils_spec.rb for more

    subject { described_class.new(:key, 1, :second) }

    it 'saves the interval in original and microsecond format' do
      expect(subject.interval).to be :second
      expect(subject.instance_variable_get(:@interval_usec)).to be 10**6
    end
  end

  describe '#limit' do
    let(:limiter) { described_class.new(:key, 3, :second) }

    it 'works' do
      expect {|b| limiter.limit(&b) }.to yield_control
      expect(limiter.limit { 123 }).to eq 123
    end

    it 'works without a block' do
      expect(limiter.limit).to be_a Berater::Lock
    end

    it 'limits excessive calls' do
      3.times { limiter.limit }

      expect(limiter).to be_overrated
    end

    it 'limit resets over time, with millisecond precision' do
      3.times { limiter.limit }
      expect(limiter).to be_overrated

      # travel forward to just before the count decrements
      Timecop.freeze(0.333)
      expect(limiter).to be_overrated

      # traveling one more millisecond will decrement the count
      Timecop.freeze(0.001)
      limiter.limit
      expect(limiter).to be_overrated

      # traveling 1 second will reset the count
      Timecop.freeze(1)

      3.times { limiter.limit }
      expect(limiter).to be_overrated
    end

    context 'when capacity is a Float' do
      let(:limiter) { described_class.new(:key, 1.5, :second) }

      it 'still works' do
        limiter.limit
        expect(limiter).not_to be_overrated

        expect { limiter.limit }.to be_overrated

        limiter.limit(cost: 0.5)
      end
    end

    it 'accepts a dynamic capacity' do
      limiter = described_class.new(:key, 1, :second)

      expect { limiter.limit(capacity: 0) }.to be_overrated
      5.times { limiter.limit(capacity: 10) }
      expect { limiter }.to be_overrated
    end

    context 'works with cost parameter' do
      it { expect { limiter.limit(cost: 4) }.to be_overrated }

      it 'works within limit' do
        limiter.limit(cost: 3)
        expect { limiter.limit }.to be_overrated
      end

      it 'resets over time' do
        limiter.limit(cost: 3)
        expect(limiter).to be_overrated

        Timecop.freeze(1)
        expect(limiter).not_to be_overrated
      end

      it 'can be a Float' do
        2.times { limiter.limit(cost: 1.5) }
        expect(limiter).to be_overrated
      end
    end

    context 'with same key, different limiters' do
      let(:limiter_one) { described_class.new(:key, 1, :second) }
      let(:limiter_two) { described_class.new(:key, 1, :second) }

      it 'works as expected' do
        expect(limiter_one.limit).not_to be_overrated

        expect(limiter_one).to be_overrated
        expect(limiter_two).to be_overrated
      end
    end

    context 'with different keys, different limiters' do
      let(:limiter_one) { described_class.new(:one, 1, :second) }
      let(:limiter_two) { described_class.new(:two, 2, :second) }

      it 'works as expected' do
        expect(limiter_one.limit).not_to be_overrated
        expect(limiter_two.limit).not_to be_overrated

        expect(limiter_one).to be_overrated
        expect(limiter_two.limit).not_to be_overrated

        expect(limiter_one).to be_overrated
        expect(limiter_two).to be_overrated
      end
    end
  end

  describe '#overloaded?' do
    let(:limiter) { described_class.new(:key, 1, :second) }

    it 'works' do
      expect(limiter.overloaded?).to be false
      limiter.limit
      expect(limiter.overloaded?).to be true
      Timecop.freeze(1)
      expect(limiter.overloaded?).to be false
    end
  end

  describe '#to_s' do
    def check(capacity, interval, expected)
      expect(
        described_class.new(:key, capacity, interval).to_s
      ).to match(expected)
    end

    it 'works with symbols' do
      check(1, :second, /1 per second/)
      check(1, :minute, /1 per minute/)
      check(1, :hour, /1 per hour/)
    end

    it 'works with strings' do
      check(1, 'second', /1 per second/)
      check(1, 'minute', /1 per minute/)
      check(1, 'hour', /1 per hour/)
    end

    it 'works with integers' do
      check(1, 1, /1 every second/)
      check(1, 2, /1 every 2 seconds/)
      check(2, 3, /2 every 3 seconds/)
    end
  end

end
