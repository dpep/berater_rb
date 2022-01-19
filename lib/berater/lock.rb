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

    @@async_work = Queue.new
    Thread.new { async_release }

    def locked?
      @released_at.nil?
    end

    def release
      raise 'lock already released' unless locked?

      # @release_fn&.call
      if @release_fn # && async
        @@async_work << @release_fn
      end

      @released_at = Time.now

      true
    end

    private

    def self.async_release
      loop do
        @@async_work.pop.call
      end
    end

  end
end
