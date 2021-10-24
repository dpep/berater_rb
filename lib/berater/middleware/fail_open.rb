require 'set'

module Berater
  module Middleware
    class FailOpen
      ERRORS = Set[
        Redis::BaseConnectionError,
      ]

      def initialize(errors: nil, on_fail: nil)
        @errors = errors || ERRORS
        @on_fail = on_fail
      end

      def call(*, **opts)
        yield.tap do |lock|
          # wrap lock.release so it fails open

          # save reference to original function
          release_fn = lock.method(:release)

          # make bound variables accessible to block
          errors = @errors
          on_fail = @on_fail

          lock.define_singleton_method(:release) do
            release_fn.call
          rescue *errors => e
            on_fail&.call(e)
            false
          end
        end
      rescue *@errors => e
        @on_fail&.call(e)

        # fail open by faking a lock
        Berater::Lock.new(opts[:capacity], -1)
      end
    end
  end
end