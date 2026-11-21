describe Berater::Heartbeat do
  def entries(heartbeat = described_class.instance)
    heartbeat.instance_variable_get(:@entries)
  end

  describe '.lease_ttl' do
    def expect_lease_ttl(interval, expected)
      Berater.heartbeat_interval = interval
      expect(described_class.lease_ttl).to eq expected
    end

    it 'derives from the heartbeat interval, with wiggle room' do
      expect_lease_ttl(5, 11_000)
      expect_lease_ttl(1, 3_000)
      expect_lease_ttl(0.5, 2_000)
      expect_lease_ttl(:minute, 121_000)
    end

    it 'is disabled along with heartbeats' do
      expect_lease_ttl(nil, nil)
      expect_lease_ttl(0, nil)
    end
  end

  context 'with a ConcurrencyLimiter' do
    let(:limiter) { Berater::ConcurrencyLimiter.new(:key, 1, timeout: 30) }
    let(:heartbeat) { described_class.instance }

    it 'registers locks upon acquisition' do
      lock = limiter.limit
      expect(entries.size).to be 1

      lock.release
      expect(entries).to be_empty
    end

    it 'does not register locks with short timeouts' do
      Berater::ConcurrencyLimiter.new(:key, 1, timeout: 1).limit
      expect(entries).to be_empty
    end

    it 'does not register utilization checks' do
      limiter.utilization
      expect(entries).to be_empty
    end

    it 'does not register when heartbeats are disabled' do
      Berater.heartbeat_interval = nil

      limiter.limit
      expect(entries).to be_empty
    end

    it 'reclaims locks from dead processes once the lease expires' do
      limiter.limit
      heartbeat.reset # simulate process death

      expect(limiter).to be_overloaded

      Timecop.freeze(12)
      expect(limiter).not_to be_overloaded
    end

    it 'renews leases on held locks' do
      limiter.limit

      Timecop.freeze(6)
      heartbeat.beat

      # the original lease would have expired by now
      Timecop.freeze(6)
      expect(limiter).to be_overloaded

      # once renewals stop, the lease expires
      heartbeat.reset
      Timecop.freeze(12)
      expect(limiter).not_to be_overloaded
    end

    it 'respects timeout as the max hold time, with millisecond precision' do
      limiter.limit

      5.times do
        Timecop.freeze(5)
        heartbeat.beat
      end

      Timecop.freeze(4.999)
      expect(limiter).to be_overloaded

      Timecop.freeze(0.001)
      expect(limiter).not_to be_overloaded
    end

    it 'stops renewing locks which reached their max hold time' do
      limiter.limit

      Timecop.freeze(31)
      heartbeat.beat

      expect(entries).to be_empty
      expect(limiter).not_to be_overloaded
    end

    it 'does not resurrect released locks' do
      lock = limiter.limit
      entry = entries.keys.first
      lock.release

      heartbeat.register(**entry.to_h)
      heartbeat.beat

      expect(limiter).not_to be_overloaded
    end

    it 'tolerates redis errors, deferring to the next beat' do
      limiter.limit
      allow(Berater.redis).to receive(:pipelined).and_raise(Redis::ConnectionError)

      expect { heartbeat.beat }.not_to raise_error
    end
  end

  describe 'background thread' do
    let(:heartbeat) { described_class.new }

    def register(**opts)
      heartbeat.register(
        redis: Berater.redis,
        cache_key: 'Berater:test:heartbeat',
        lock_ids: [ 1 ],
        acquired_at: (Time.now.to_f * 10**3).to_i,
        timeout: 30_000,
        **opts,
      )
    end

    it 'starts upon registration and beats periodically' do
      Berater.heartbeat_interval = 0.05
      expect(heartbeat).to receive(:beat).at_least(:once)

      register
      expect(heartbeat.instance_variable_get(:@thread)).to be_alive

      sleep 0.2
    end

    it 'prunes inherited entries after a fork' do
      register
      expect(entries(heartbeat).size).to be 1

      allow(Process).to receive(:pid).and_return(0)

      register(lock_ids: [ 2 ])
      expect(entries(heartbeat).size).to be 1
    end
  end
end
