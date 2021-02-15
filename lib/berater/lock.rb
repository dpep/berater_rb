module Berater
  class Lock

    attr_reader :limiter, :id, :contention

    def initialize(limiter, id, contention, release_fn = nil)
      @limiter = limiter
      @id = id
      @contention = contention
      @locked_at = Time.now
      @release_fn = release_fn
      @released_at = nil
    end

    def locked?
      @released_at.nil? && !expired?
    end

    def expired?
      timeout > 0 && @locked_at + timeout < Time.now
    end

    def release
      raise 'lock expired' if expired?
      raise 'lock already released' unless locked?

      @released_at = Time.now
      @release_fn ? @release_fn.call : true
    end

    private def timeout
      limiter.respond_to?(:timeout) ? limiter.timeout : 0
    end

  end
end
