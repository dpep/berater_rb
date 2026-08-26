require 'berater/utils'

module Berater
  class Heartbeat

    LEASE_FACTOR = 2

    # wiggle room for transit and execution time
    LEASE_GRACE_MS = 1_000

    Entry = Struct.new(:redis, :cache_key, :lock_ids, :acquired_at, :timeout)

    class << self
      def interval_msec
        interval = Berater.heartbeat_interval
        return unless interval

        msec = Berater::Utils.to_msec(interval)
        msec if msec > 0
      end

      def lease_ttl
        msec = interval_msec
        msec && msec * LEASE_FACTOR + LEASE_GRACE_MS
      end

      def instance
        @instance ||= new
      end

      def register(...)
        instance.register(...)
      end

      def deregister(...)
        instance.deregister(...)
      end

      def reset
        @instance&.reset
      end
    end

    def initialize
      @entries = {}
      @mutex = ::Mutex.new
      @pid = Process.pid
    end

    def register(redis:, cache_key:, lock_ids:, acquired_at:, timeout:)
      entry = Entry.new(redis, cache_key, lock_ids, acquired_at, timeout)

      @mutex.synchronize do
        prune_after_fork
        @entries[entry] = true
        start_thread
      end

      entry
    end

    def deregister(entry)
      @mutex.synchronize { @entries.delete(entry) }
    end

    # renew leases for all registered locks
    def beat
      now = (Time.now.to_f * 10**3).to_i
      ttl = self.class.lease_ttl

      entries = @mutex.synchronize { @entries.keys }

      entries.group_by { |e| [ e.redis, e.cache_key ] }.each do |(redis, cache_key), group|
        # stop renewing locks which reached their max hold time
        expired, live = group.partition { |e| (now - e.acquired_at) >= e.timeout }
        expired.each { |e| deregister(e) }

        next if ttl.nil? || live.empty?

        scores = live.flat_map do |e|
          # cap the lease so timeout remains the max hold time
          score = [ now, e.acquired_at + e.timeout - ttl ].min
          e.lock_ids.map { |id| [ score, id ] }
        end

        begin
          redis.pipelined do |pipeline|
            # renew held locks, without resurrecting reclaimed ones
            pipeline.zadd(cache_key, scores, xx: true)
            pipeline.pexpire(cache_key, ttl)
          end
        rescue StandardError
          # eg. connection error.  locks may expire early, but
          # the next beat will try again
        end
      end
    end

    def reset
      @mutex.synchronize { @entries.clear }
    end

    private

    def start_thread
      return if @thread&.alive?

      @thread = Thread.new do
        Thread.current.name = 'berater-heartbeat'

        loop do
          msec = self.class.interval_msec
          sleep(msec ? msec / 10**3.0 : 1)

          beat rescue nil
        end
      end
    end

    def prune_after_fork
      return if @pid == Process.pid

      # child process inherits the registry, but locks belong to the parent
      @pid = Process.pid
      @entries.clear
      @thread = nil
    end

  end
end
