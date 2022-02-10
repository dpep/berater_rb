require 'ddtrace'

module Berater
  module Middleware
    class Trace
      def initialize(tracer: nil)
        @tracer = tracer
      end

      def call(limiter, **)
        tracer.trace('Berater.limit') do |span|
          begin
            lock = yield
          rescue Exception => error
            # capture exception for reporting, then propagate
            raise
          ensure
            span.set_tag('capacity', limiter.capacity)
            span.set_tag('contention', lock.contention) if lock
            span.set_tag('key', limiter.key)
            span.set_tag('limiter', limiter.class.to_s.split(':')[-1])

            if error
              if error.is_a?(Berater::Overloaded)
                span.set_tag('overloaded', true)
              else
                span.set_tag('error', error.class.to_s.gsub('::', '_'))
              end
            end
          end
        end
      end

      private

      def tracer
        @tracer || Datadog.tracer
      end
    end
  end
end
