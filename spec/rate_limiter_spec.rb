describe Berater::RateLimiter do
  before { Berater.mode = :rate }

  let(:redis) { Berater.redis }

  describe '.new' do
    it 'initializes' do
      limiter = described_class.new(:key, 1, :second, redis: redis)
      expect(limiter.redis).to be redis
    end
  end

  describe 'count' do
    def expect_count(count)
      limiter = described_class.new(:key, count, :second, redis: redis)
      expect(limiter.count).to eq count
    end

    it { expect_count(0) }
    it { expect_count(1) }
    it { expect_count(100) }

    context 'with erroneous values' do
      def expect_bad_count(count)
        expect do
          described_class.new(:key, count, :second, redis: redis)
        end.to raise_error ArgumentError
      end

      it { expect_bad_count(0.5) }
      it { expect_bad_count(-1) }
      it { expect_bad_count('1') }
      it { expect_bad_count(:one) }
    end
  end

  describe 'interval' do
    def expect_interval(interval, expected)
      limiter = described_class.new(:key, 1, interval, redis: redis)
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
          described_class.new(:key, 1, interval, redis: redis)
        end.to raise_error(ArgumentError)
      end

      it { expect_bad_interval(-1) }
      it { expect_bad_interval(:secondz) }
      it { expect_bad_interval('huor') }
    end
  end

  describe '.limit' do
    let(:limiter) { described_class.new(:key, 3, :second, redis: redis) }

    it 'works' do
      expect(limiter.limit).to eq 1
    end

    it 'counts' do
      expect(limiter.limit).to eq 1
      expect(limiter.limit).to eq 2
      expect(limiter.limit).to eq 3
    end

    it 'limits excessive calls' do
      3.times { limiter.limit }

      expect { limiter.limit }.to raise_error(Berater::RateLimiter::Overrated)

      # same same
      expect { limiter.limit }.to raise_error(Berater::LimitExceeded)
    end
  end

  describe 'Berater.limiter' do
    subject { Berater.limiter(:key, 1, :second) }

    it 'type is derived from the mode' do
      is_expected.to be_a described_class
    end

    it 'inherits redis' do
      expect(subject.redis).to be Berater.redis
    end

    it 'allows a new redis connection to be specified' do
      limiter = Berater.limiter(:key, 1, :second, redis: :fake)
      expect(limiter.redis).not_to be Berater.redis
    end
  end

  describe 'Berater.limit' do
    it 'works' do
      expect(Berater.limit(:key, 1, :second)).to eq 1
    end

    it 'limits excessive calls' do
      expect(Berater.limit(:key, 1, :second)).to eq 1

      expect {
        Berater.limit(:key, 1, :second)
      }.to raise_error(Berater::RateLimiter::Overrated)

      # same same
      expect {
        Berater.limit(:key, 1, :second)
      }.to raise_error(Berater::LimitExceeded)
    end

    it 'allows a new redis connection to be specified' do
      expect do
        Berater.limit(:key, 1, :second, redis: :fake)
      end.to raise_error(NoMethodError)
    end
  end

end
