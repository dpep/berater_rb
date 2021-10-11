require 'set'

module Berater
  module Middleware
    class FailOpen
      ERRORS = Set[
        Redis::BaseConnectionError,
      ]

      def initialize(on_fail: nil)
        @on_fail = on_fail
      end

      def call(*, **opts)
        yield.tap do |lock|
          # wrap lock.release so it fails open

          # save reference to original function
          release_fn = lock.method(:release)

          # make bound variable accessible to block
          on_fail = @on_fail

          lock.define_singleton_method(:release) do
            release_fn.call
          rescue *ERRORS => e
            on_fail&.call(e)
            false
          end
        end
      rescue *ERRORS => e
        @on_fail&.call(e)

        # fail open by faking a lock
        Berater::Lock.new(opts[:capacity], 0)
      end
    end
  end
end
