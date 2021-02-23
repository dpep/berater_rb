describe Berater::RateLimiter do
  it_behaves_like 'a limiter', Berater.new(:key, :rate, 3, :second)

  describe '.new' do
    let(:limiter) { described_class.new(:key, 1, :second) }

    it 'initializes' do
      expect(limiter.key).to be :key
      expect(limiter.count).to eq 1
      expect(limiter.interval).to eq :second
    end

    it 'has default values' do
      expect(limiter.redis).to be Berater.redis
    end
  end

  describe '#count' do
    def expect_count(count)
      limiter = described_class.new(:key, count, :second)
      expect(limiter.count).to eq count
    end

    it { expect_count(0) }
    it { expect_count(1) }
    it { expect_count(100) }

    context 'with erroneous values' do
      def expect_bad_count(count)
        expect do
          described_class.new(:key, count, :second)
        end.to raise_error ArgumentError
      end

      it { expect_bad_count(0.5) }
      it { expect_bad_count(-1) }
      it { expect_bad_count('1') }
      it { expect_bad_count(:one) }
    end
  end

  describe '#interval' do
    def expect_interval(interval, expected)
      limiter = described_class.new(:key, 1, interval)
      expect(limiter.interval).to eq expected
    end

    context 'with ints' do
      it { expect_interval(0, 0) }
      it { expect_interval(1, 1) }
      it { expect_interval(33, 33) }
    end

    context 'with symbols' do
      it { expect_interval(:sec, :second) }
      it { expect_interval(:second, :second) }
      it { expect_interval(:seconds, :second) }

      it { expect_interval(:min, :minute) }
      it { expect_interval(:minute, :minute) }
      it { expect_interval(:minutes, :minute) }

      it { expect_interval(:hour, :hour) }
      it { expect_interval(:hours, :hour) }
    end

    context 'with strings' do
      it { expect_interval('sec', :second) }
      it { expect_interval('minute', :minute) }
      it { expect_interval('hours', :hour) }
    end

    context 'with erroneous values' do
      def expect_bad_interval(interval)
        expect do
          described_class.new(:key, 1, interval)
        end.to raise_error(ArgumentError)
      end

      it { expect_bad_interval(-1) }
      it { expect_bad_interval(:secondz) }
      it { expect_bad_interval('huor') }
    end

    context 'interprets values' do
      def expect_sec(interval, expected)
        limiter = described_class.new(:key, 1, interval)
        expect(limiter.instance_variable_get(:@interval_sec)).to eq expected
      end

      it { expect_sec(:second, 1) }
      it { expect_sec(:minute, 60) }
      it { expect_sec(:hour, 3600) }
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

    it 'accepts a dynamic capacity' do
      limiter = described_class.new(:key, 1, :second)

      expect { limiter.limit(capacity: 0) }.to be_overrated
      5.times { limiter.limit(capacity: 10) }
      expect { limiter.limit }.to be_overrated
    end

    it 'accepts a cost param' do
      expect { limiter.limit(cost: 4) }.to be_overrated

      limiter.limit(cost: 3)
      expect { limiter.limit }.to be_overrated
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

  describe '#to_s' do
    def check(count, interval, expected)
      expect(
        described_class.new(:key, count, interval).to_s
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

    it 'normalizes' do
      check(1, :sec, /1 per second/)
      check(1, :seconds, /1 per second/)

      check(1, :min, /1 per minute/)
      check(1, :minutes, /1 per minute/)

      check(1, :hours, /1 per hour/)
    end

    it 'works with integers' do
      check(1, 1, /1 every second/)
      check(1, 2, /1 every 2 seconds/)
      check(2, 3, /2 every 3 seconds/)
    end
  end

end
