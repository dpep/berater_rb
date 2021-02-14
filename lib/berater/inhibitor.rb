module Berater
  class Inhibitor < BaseLimiter

    class Inhibited < Overloaded; end

    def initialize(key = :inhibitor, *args, **opts)
      super(key, **opts)
    end

    def limit
      raise Inhibited
    end

  end
end
