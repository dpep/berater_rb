module Berater
  class Inhibitor < Limiter

    class Inhibited < Overloaded; end

    def initialize(key = :inhibitor, *args, **opts)
      super(key, **opts)
    end

    def limit(**opts)
      raise Inhibited
    end

  end
end
