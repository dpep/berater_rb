require 'fiber'

describe Berater::ConcurrencyLimiter do
  before { Berater.mode = :concurrency }

  let(:redis) { Berater.redis }

  def do_work
    limiter.limit do
      # pause so workers are guarenteed to run simultaneously if at all
      Fiber.yield
    end
  rescue Berater::LimitExceeded
    nil
  end

  describe '.new' do
    it 'initializes' do
      limiter = described_class.new(:key, 1, redis: redis)
      expect(limiter.redis).to be redis
    end
  end

  describe 'capacity' do
    def expect_capacity(capacity)
      limiter = described_class.new(:key, capacity, redis: redis)
      expect(limiter.capacity).to eq capacity
    end

    it { expect_capacity(0) }
    it { expect_capacity(1) }
    it { expect_capacity(10_000) }

    context 'with erroneous values' do
      def expect_bad_capacity(capacity)
        expect do
          described_class.new(:key, capacity, redis: redis)
        end.to raise_error ArgumentError
      end

      it { expect_bad_capacity(0.5) }
      it { expect_bad_capacity(-1) }
      it { expect_bad_capacity('1') }
      it { expect_bad_capacity(:one) }
    end
  end

  describe 'timeout' do
    def expect_timeout(timeout)
      limiter = described_class.new(:key, 1, timeout: timeout, redis: redis)
      expect(limiter.timeout).to eq timeout
    end

    it { expect_timeout(0) }
    it { expect_timeout(1) }
    it { expect_timeout(10_000) }

    context 'with erroneous values' do
      def expect_bad_timeout(timeout)
        expect do
          described_class.new(:key, 1, timeout: timeout, redis: redis)
        end.to raise_error ArgumentError
      end

      it { expect_bad_timeout(0.5) }
      it { expect_bad_timeout(-1) }
      it { expect_bad_timeout('1') }
      it { expect_bad_timeout(:one) }
    end
  end

  describe '.limit' do
    let(:limiter) { described_class.new(:key, 3, timeout: 30, redis: redis) }

    it 'works' do
      expect {|b| limiter.limit(&b) }.to yield_control
    end

    it 'works many times if workers complete and return tokens' do
      30.times do
        expect {|b| limiter.limit(&b) }.to yield_control
      end
    end

    it 'works concurrently within capacity' do
      workers = 3.times.map do
        Fiber.new { do_work }
      end

      expect(workers.count(&:alive?)).to eq 3

      # start work and pause
      workers.each(&:resume)
      expect(workers.count(&:alive?)).to eq 3

      # complete work
      workers.each(&:resume)
      expect(workers.count(&:alive?)).to eq 0
    end

    it 'limits excessive calls' do
      workers = 5.times.map do
        Fiber.new { do_work }
      end

      expect(workers.count(&:alive?)).to eq 5

      # start work and pause
      workers.each(&:resume)
      expect(workers.count(&:alive?)).to eq 3

      # all tokens are held by paused workers
      expect { limiter.limit }.to raise_error(Berater::ConcurrencyLimiter::Incapacitated)

      # same same
      expect { limiter.limit }.to raise_error(Berater::LimitExceeded)
    end
  end

  describe 'Berater.limiter' do
    subject { Berater.limiter(:key, 1) }

    it 'type is derived from the mode' do
      is_expected.to be_a described_class
    end

    it 'inherits redis' do
      expect(subject.redis).to be Berater.redis
    end

    it 'allows a new redis connection to be specified' do
      limiter = Berater.limiter(:key, 1, redis: :fake)
      expect(limiter.redis).not_to be Berater.redis
    end
  end

  describe 'Berater.limit' do
    it 'works' do
      expect {|b| Berater.limit(:key, 1, &b) }.to yield_control
    end

    it 'allows a new redis connection to be specified' do
      expect do
        Berater.limit(:key, 1, redis: :fake)
      end.to raise_error(NoMethodError)
    end
  end

end
