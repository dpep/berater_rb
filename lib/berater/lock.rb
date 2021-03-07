module Berater
  class Lock

    attr_reader :capacity, :contention

    def initialize(capacity, contention, release_fn = nil)
      @capacity = capacity
      @contention = contention
      @locked_at = Time.now
      @release_fn = release_fn
      @released_at = nil
    end

    def locked?
      @released_at.nil?
    end

    def release
      raise 'lock already released' unless locked?

      @released_at = Time.now
      @release_fn ? @release_fn.call : true
    end

  end
end
