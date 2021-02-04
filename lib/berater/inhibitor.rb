module Berater
  class Inhibitor < BaseLimiter

    class Inhibited < Overloaded; end

    def initialize(*args, **opts)
      super(**opts)
    end

    def limit(**opts, &block)
      unless opts.empty?
        return self.class.new(
          **options.merge(opts)
        ).limit(&block)
      end

      raise Inhibited
    end

  end
end
