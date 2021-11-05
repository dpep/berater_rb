module Berater
  module Middleware
    class Statsd
      def initialize(client, tags: {})
        @client = client
        @tags = tags
      end

      def call(limiter, **opts)
        duration = -Process.clock_gettime(Process::CLOCK_MONOTONIC)
        lock = yield
      rescue Exception => error
        # note exception and propagate
        raise
      ensure
        duration += Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration = (duration * 1_000).round(2) # milliseconds

        tags = build_tags(limiter, opts)

        @client.timing(
          'berater.limiter.limit',
          duration,
          tags: tags.merge(overloaded: !lock),
        )

        @client.gauge(
          'berater.limiter.capacity',
          limiter.capacity,
          tags: tags,
        )

        if lock && lock.contention > 0 # not a failsafe lock
          @client.gauge(
            'berater.lock.capacity',
            lock.capacity,
            tags: tags,
          )
          @client.gauge(
            'berater.limiter.contention',
            lock.contention,
            tags: tags,
          )
        end

        if error
          if error.is_a?(Berater::Overloaded)
            # overloaded, so contention >= capacity
            @client.gauge(
              'berater.limiter.contention',
              limiter.capacity,
              tags: tags,
            )
          else
            @client.increment(
              'berater.limiter.error',
              tags: tags.merge(type: error.class.to_s.gsub('::', '_'))
            )
          end
        end
      end

      private

      def build_tags(limiter, opts)
        tags = {
          key: limiter.key,
          limiter: limiter.class.to_s.split(':')[-1],
        }

        # append custom tags
        if @tags.respond_to?(:call)
          tags.merge!(@tags.call(limiter, **opts) || {})
        else
          tags.merge!(@tags)
        end

        tags.merge!(opts.fetch(:tags, {}))
      end
    end
  end
end
