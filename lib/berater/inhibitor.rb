module Berater
  class Inhibitor < Limiter

    class Inhibited < Overloaded; end

    def initialize(key = :inhibitor, *args, **opts)
      super(key, 0, **opts)
    end

    protected def acquire_lock(*)
      raise Inhibited
    end

  end
end
