module Berater
  class Unlimiter < BaseLimiter

    def initialize(*args, **opts)
      super(**opts)
    end

    def limit(**opts, &block)
      unless opts.empty?
        return self.class.new(
          **options.merge(opts)
        ).limit(&block)
      end

      yield if block_given?
    end

  end
end
