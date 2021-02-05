describe Berater::ConcurrencyLimiter do
  before { Berater.mode = :concurrency }

  describe '.new' do
    let(:limiter) { described_class.new(1) }

    it 'initializes' do
      expect(limiter.capacity).to be 1
    end

    it 'has default values' do
      expect(limiter.key).to eq described_class.to_s
      expect(limiter.redis).to be Berater.redis
    end
  end

  describe '#capacity' do
    def expect_capacity(capacity)
      limiter = described_class.new(capacity)
      expect(limiter.capacity).to eq capacity
    end

    it { expect_capacity(0) }
    it { expect_capacity(1) }
    it { expect_capacity(10_000) }

    context 'with erroneous values' do
      def expect_bad_capacity(capacity)
        expect do
          described_class.new(capacity)
        end.to raise_error ArgumentError
      end

      it { expect_bad_capacity(0.5) }
      it { expect_bad_capacity(-1) }
      it { expect_bad_capacity('1') }
      it { expect_bad_capacity(:one) }
    end
  end

  describe '#timeout' do
    def expect_timeout(timeout)
      limiter = described_class.new(1, timeout: timeout)
      expect(limiter.timeout).to eq timeout
    end

    it { expect_timeout(0) }
    it { expect_timeout(1) }
    it { expect_timeout(10_000) }

    context 'with erroneous values' do
      def expect_bad_timeout(timeout)
        expect do
          described_class.new(1, timeout: timeout)
        end.to raise_error ArgumentError
      end

      it { expect_bad_timeout(0.5) }
      it { expect_bad_timeout(-1) }
      it { expect_bad_timeout('1') }
      it { expect_bad_timeout(:one) }
    end
  end

  describe '#limit' do
    let(:limiter) { described_class.new(2, timeout: 1) }

    it 'works' do
      expect {|b| limiter.limit(&b) }.to yield_control
    end

    it 'works many times if workers complete and return locks' do
      30.times do
        expect {|b| limiter.limit(&b) }.to yield_control
      end
    end

    it 'limits excessive calls' do
      expect(limiter.limit).to be_a Berater::ConcurrencyLimiter::Lock
      expect(limiter.limit).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter }.to be_incapacitated
    end

    it 'times out locks' do
      expect(limiter.limit).to be_a Berater::ConcurrencyLimiter::Lock
      expect(limiter.limit).to be_a Berater::ConcurrencyLimiter::Lock
      expect { limiter }.to be_incapacitated

      Timecop.travel(1)

      expect(limiter.limit).to be_a Berater::ConcurrencyLimiter::Lock
      expect(limiter.limit).to be_a Berater::ConcurrencyLimiter::Lock
      expect { limiter }.to be_incapacitated
    end
  end

  context 'with same key, different limiters' do
    let(:limiter_one) { described_class.new(1) }
    let(:limiter_two) { described_class.new(1) }

    it { expect(limiter_one.key).to eq limiter_two.key }

    it 'works as expected' do
      expect(limiter_one.limit).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter_one }.to be_incapacitated
      expect { limiter_two }.to be_incapacitated
    end
  end

  context 'with different keys, same limiter' do
    let(:limiter) { described_class.new(1) }

    it 'works as expected' do
      one_lock = limiter.limit(key: :one)
      expect(one_lock).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter.limit(key: :one) {} }.to be_incapacitated
      expect { limiter.limit(key: :two) {} }.not_to be_incapacitated

      two_lock = limiter.limit(key: :two)
      expect(two_lock).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter.limit(key: :one) {} }.to be_incapacitated
      expect { limiter.limit(key: :two) {} }.to be_incapacitated

      one_lock.release
      expect { limiter.limit(key: :one) {} }.not_to be_incapacitated
      expect { limiter.limit(key: :two) {} }.to be_incapacitated

      two_lock.release
      expect { limiter.limit(key: :one) {} }.not_to be_incapacitated
      expect { limiter.limit(key: :two) {} }.not_to be_incapacitated
    end
  end

  context 'with same key, different capacities' do
    let(:limiter_one) { described_class.new(1) }
    let(:limiter_two) { described_class.new(2) }

    it { expect(limiter_one.capacity).not_to eq limiter_two.capacity }

    it 'works as expected' do
      one_lock = limiter_one.limit
      expect(one_lock).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter_one }.to be_incapacitated
      expect { limiter_two }.not_to be_incapacitated

      two_lock = limiter_two.limit
      expect(two_lock).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter_one }.to be_incapacitated
      expect { limiter_two }.to be_incapacitated

      one_lock.release
      expect { limiter_one }.to be_incapacitated
      expect { limiter_two }.not_to be_incapacitated

      two_lock.release
      expect { limiter_one }.not_to be_incapacitated
      expect { limiter_two }.not_to be_incapacitated
    end
  end

  context 'with different keys, different limiters' do
    let(:limiter_one) { described_class.new(1, key: :one) }
    let(:limiter_two) { described_class.new(1, key: :two) }

    it 'works as expected' do
      expect { limiter_one }.not_to be_incapacitated
      expect { limiter_two }.not_to be_incapacitated

      one_lock = limiter_one.limit
      expect(one_lock).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter_one }.to be_incapacitated
      expect { limiter_two }.not_to be_incapacitated

      two_lock = limiter_two.limit
      expect(two_lock).to be_a Berater::ConcurrencyLimiter::Lock

      expect { limiter_one }.to be_incapacitated
      expect { limiter_two }.to be_incapacitated
    end
  end

end
