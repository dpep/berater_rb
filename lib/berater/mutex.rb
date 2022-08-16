module Berater
  module Mutex
    def self.included(base)
      # add class methods
      base.instance_eval do
        def synchronize(subkey = nil, **opts, &block)
          key = [ 'Mutex', name&.delete(':') || object_id, subkey ].compact.join(':')

          Berater::ConcurrencyLimiter(key, 1, **mutex_options.merge(opts)) do
            yield if block_given?
          end
        end

        def mutex_options(**kwargs)
          (@mutex_options ||= {}).update(kwargs)
        end
      end
    end

    def synchronize(...)
      self.class.synchronize(...)
    end

    def self.extend_object(base)
      included(base)
    end
  end
end
