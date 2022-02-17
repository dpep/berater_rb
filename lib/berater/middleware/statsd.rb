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
        # capture exception for reporting, then propagate
        raise
      ensure
        duration += Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration = (duration * 1_000).round(2) # milliseconds

        tags = build_tags(limiter, opts)

        @client.timing(
          'berater.limiter.limit',
          duration,
          tags: tags,
        )

        @client.gauge(
          'berater.limiter.capacity',
          limiter.capacity,
          tags: tags,
        )

        if lock
          @client.increment(
            'berater.lock.acquired',
            tags: tags,
          )

          if lock.contention > 0 # not a failsafe lock
            @client.gauge(
              'berater.lock.capacity',
              lock.capacity,
              tags: tags,
            )
            @client.gauge(
              'berater.lock.contention',
              lock.contention,
              tags: tags,
            )
          end
        end

        if error
          if error.is_a?(Berater::Overloaded)
            @client.increment(
              'berater.limiter.overloaded',
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

        # append global custom tags
        if @tags
          if @tags.respond_to?(:call)
            tags.merge!(@tags.call(limiter, **opts) || {})
          else
            tags.merge!(@tags)
          end
        end

        # append call specific custom tags
        tags.merge!(opts[:tags]) if opts[:tags]

        tags
      end
    end
  end
end
