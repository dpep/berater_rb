describe Berater::RateLimiter do
  before { Berater.mode = :rate }

  describe '.new' do
    let(:limiter) { described_class.new(1, :second) }

    it 'initializes' do
      expect(limiter.count).to eq 1
      expect(limiter.interval).to eq 1
    end

    it 'has default values' do
      expect(limiter.key).to eq described_class.to_s
      expect(limiter.redis).to be Berater.redis
    end
  end

  describe '#count' do
    def expect_count(count)
      limiter = described_class.new(count, :second)
      expect(limiter.count).to eq count
    end

    it { expect_count(0) }
    it { expect_count(1) }
    it { expect_count(100) }

    context 'with erroneous values' do
      def expect_bad_count(count)
        expect do
          described_class.new(count, :second)
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
      limiter = described_class.new(1, interval)
      expect(limiter.interval).to eq expected
    end

    context 'with ints' do
      it { expect_interval(0, 0) }
      it { expect_interval(1, 1) }
      it { expect_interval(33, 33) }
    end

    context 'with symbols' do
      it { expect_interval(:sec, 1) }
      it { expect_interval(:second, 1) }
      it { expect_interval(:seconds, 1) }

      it { expect_interval(:min, 60) }
      it { expect_interval(:minute, 60) }
      it { expect_interval(:minutes, 60) }

      it { expect_interval(:hour, 3600) }
      it { expect_interval(:hours, 3600) }
    end

    context 'with strings' do
      it { expect_interval('sec', 1) }
      it { expect_interval('minute', 60) }
      it { expect_interval('hours', 3600) }
    end

    context 'with erroneous values' do
      def expect_bad_interval(interval)
        expect do
          described_class.new(1, interval)
        end.to raise_error(ArgumentError)
      end

      it { expect_bad_interval(-1) }
      it { expect_bad_interval(:secondz) }
      it { expect_bad_interval('huor') }
    end
  end

  describe '#limit' do
    let(:limiter) { described_class.new(3, :second) }

    it 'works' do
      expect(limiter.limit).to eq 1
    end

    it 'counts' do
      expect(limiter.limit).to eq 1
      expect(limiter.limit).to eq 2
      expect(limiter.limit).to eq 3
    end

    it 'yields' do
      expect {|b| limiter.limit(&b) }.to yield_control
      expect(limiter.limit { 123 }).to eq 123
    end

    it 'limits excessive calls' do
      3.times { limiter.limit }

      expect { limiter.limit }.to be_overrated
    end
  end

  context 'with same key, different limiters' do
    let(:limiter_one) { described_class.new(1, :second) }
    let(:limiter_two) { described_class.new(1, :second) }

    it 'works as expected' do
      expect(limiter_one.limit).to eq 1

      expect { limiter_one.limit }.to be_overrated
      expect { limiter_two.limit }.to be_overrated
    end
  end

  context 'with different keys, same limiter' do
    let(:limiter) { described_class.new(1, :second) }

    it 'works as expected' do
      expect { limiter.limit(key: :one) }.not_to be_overrated
      expect { limiter.limit(key: :one) }.to be_overrated

      expect { limiter.limit(key: :two) }.not_to be_overrated
      expect { limiter.limit(key: :two) }.to be_overrated
    end
  end

  context 'with different keys, different limiters' do
    let(:limiter_one) { described_class.new(1, :second, key: :one) }
    let(:limiter_two) { described_class.new(2, :second, key: :two) }

    it 'works as expected' do
      expect(limiter_one.limit).to eq 1
      expect(limiter_two.limit).to eq 1

      expect { limiter_one.limit }.to be_overrated
      expect(limiter_two.limit).to eq 2

      expect { limiter_one.limit }.to be_overrated
      expect { limiter_two.limit }.to be_overrated
    end
  end

end
