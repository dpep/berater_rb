module Berater
  class Inhibitor < Limiter

    def initialize(key = :inhibitor, *args, **opts)
      super(key, 0, **opts)
    end

    protected def acquire_lock(*)
      raise Overloaded
    end

  end
end
