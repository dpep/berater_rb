module Berater
  class Inhibitor < Limiter

    class Inhibited < Overloaded; end

    def initialize(key = :inhibitor, *args, **opts)
      super(key, 0, **opts)
    end

    def limit(**opts)
      raise Inhibited
    end

    def overloaded?
      true
    end
    alias inhibited? overloaded?

  end
end
