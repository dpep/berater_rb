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
    it { expect_capacity(10_000) }

    context 'with erroneous values' do
      def expect_bad_capacity(capacity)
        expect do
          described_class.new(:key, capacity)
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
      limiter = described_class.new(:key, 1, timeout: timeout)
      expect(limiter.timeout).to eq timeout
    end

    it { expect_timeout(0) }
    it { expect_timeout(1) }
    it { expect_timeout(10_000) }

    context 'with erroneous values' do
      def expect_bad_timeout(timeout)
        expect do
          described_class.new(:key, 1, timeout: timeout)
        end.to raise_error ArgumentError
      end

      it { expect_bad_timeout(0.5) }
      it { expect_bad_timeout(-1) }
      it { expect_bad_timeout('1') }
      it { expect_bad_timeout(:one) }
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

    it 'resets over time' do
      2.times { limiter.limit }
      expect(limiter).to be_incapacitated

      Timecop.travel(30)

      2.times { limiter.limit }
      expect(limiter).to be_incapacitated
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
